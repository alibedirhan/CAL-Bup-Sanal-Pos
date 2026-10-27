import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../../application/kart_kasasi.dart';
import '../../domain/hata.dart';
import '../../domain/kart_bilgileri.dart';
import '../../domain/modeller.dart';

/// Cihazın kimlik doğrulamalı şifrelemesi (AES-256-GCM, 96 bit IV, 128 bit
/// etiket). Anahtar kullanıcı başınadır ve cihazdan dışarı çıkmaz. Anahtar
/// yoksa yalnız [olustur] ise üretilir.
abstract interface class KasaSifreleyici {
  Future<SifreliVeri> sifrele(
    String uid,
    Uint8List ekVeri,
    Uint8List duz, {
    required bool olustur,
  });
  Future<Uint8List> coz(String uid, Uint8List ekVeri, SifreliVeri veri);
}

class SifreliVeri {
  const SifreliVeri(this.iv, this.veri);
  final Uint8List iv, veri;
}

/// Kullanıcı başına tek kasa belgesi; yazma atomiktir (ya eski ya yeni belge).
abstract interface class KasaDeposu {
  Future<Map<String, Object?>?> oku(String uid);
  Future<void> yaz(String uid, Map<String, Object?> belge);
}

/// Platformdan bağımsız cihaz kart kasası. Web `web/kart_kasasi.js` ile aynı
/// sözleşme (docs/CIHAZ_KART_KASASI.md): önce taslak, sunucu onayından sonra
/// [tamamla]; ek doğrulama verisi kullanıcı/cari/kart/son dört/tarih/referansı
/// bağlar; kasada kayıt varken anahtar yoksa yeni anahtar üretilmez; bozuk
/// kayıt sessiz silinmez veya düz metne düşülmez. Hata ayrıntısı dışarı
/// çıkmaz (kart ve platform istisnası günlüğe yazılmaz).
class SifreliKasa implements KartKasasi {
  SifreliKasa(this._sifreleyici, this._depo, {String Function()? kimlikUret})
    : _kimlikUret = kimlikUret ?? _rastgeleKimlik;
  final KasaSifreleyici _sifreleyici;
  final KasaDeposu _depo;
  final String Function() _kimlikUret;
  Future<void> _sira = Future.value();

  static const _hata = PosHatasi(
    'cihaz',
    'Bu telefondaki şifreli kart bilgisine ulaşılamadı. Uygulamanın verilerini silme; yeniden dene.',
  );

  /// Kasa işlemleri sırayla yürür: aynı belgeye iki yazma çakışmaz.
  Future<T> _sirayla<T>(Future<T> Function() islem) {
    final sonuc = _sira.then((_) => islem());
    _sira = sonuc.then((_) {}, onError: (Object _) {});
    return sonuc.catchError((Object e) {
      if (e is PosHatasi) throw e;
      throw _hata;
    });
  }

  @override
  Future<String> hazirla(String uid, KartOzeti kart, KartBilgileri bilgiler) =>
      _sirayla(() async {
        _kapsam(uid, kart.cariId, kart.id);
        if (bilgiler.sonDort != kart.sonDort) throw _hata;
        final belge = await _belge(uid);
        final kimlik = _kimlikUret();
        final duz = _yuk(bilgiler);
        final SifreliVeri s;
        try {
          s = await _sifreleyici.sifrele(
            uid,
            _ekVeri(uid, kart, kimlik),
            duz,
            olustur: belge.bos,
          );
        } finally {
          _sifirla(duz);
        }
        belge.taslaklar[kimlik] = _Kayit(
          cariId: kart.cariId,
          kartId: kart.id,
          kimlik: kimlik,
          sonDort: kart.sonDort,
          ay: kart.ay,
          yil: kart.yil,
          iv: s.iv,
          veri: s.veri,
        );
        await _depo.yaz(uid, belge.toJson(uid));
        return kimlik;
      });

  @override
  Future<void> tamamla(String uid, String kayitId) =>
      _sirayla(() async => _tamamla(uid, await _belge(uid), kayitId));

  Future<void> _tamamla(String uid, _Belge belge, String kayitId) async {
    final t = belge.taslaklar.remove(kayitId);
    if (t == null) throw _hata;
    belge.kartlar[_etkin(t.cariId, t.kartId)] = t;
    await _depo.yaz(uid, belge.toJson(uid));
  }

  @override
  Future<KartBilgileri?> oku(String uid, KartOzeti kart) => _sirayla(() async {
    _kapsam(uid, kart.cariId, kart.id);
    final kayitId = kart.cihazKayitId;
    if (kayitId == null) return null;
    final belge = await _belge(uid);
    var kayit = belge.kartlar[_etkin(kart.cariId, kart.id)];
    var bekleyen = false;
    if (kayit == null || kayit.kimlik != kayitId) {
      // Sunucuya ulaşmış ama son yerel adımı yarım kalmış kart: çağıran
      // uygulama referansı önce güncel yetkili sunucu kaydında doğrular.
      kayit = belge.taslaklar[kayitId];
      if (kayit == null) return null;
      if (kayit.cariId != kart.cariId || kayit.kartId != kart.id) throw _hata;
      bekleyen = true;
    }
    if (kayit.sonDort != kart.sonDort ||
        kayit.ay != kart.ay ||
        kayit.yil != kart.yil) {
      throw _hata;
    }
    final duz = await _sifreleyici.coz(
      uid,
      _ekVeri(uid, kart, kayit.kimlik),
      SifreliVeri(kayit.iv, kayit.veri),
    );
    final KartBilgileri bilgiler;
    try {
      bilgiler = _cozYuk(duz, kart.sonDort);
    } finally {
      _sifirla(duz);
    }
    if (bekleyen) await _tamamla(uid, belge, kayitId);
    return bilgiler;
  });

  @override
  Future<void> sil(String uid, String cariId, String? kartId) =>
      _sirayla(() async {
        _kapsam(uid, cariId, kartId ?? 'tum');
        final d = await _depo.oku(uid);
        if (d == null) return;
        final belge = _Belge.fromJson(uid, d);
        bool eslesir(_Kayit k) =>
            k.cariId == cariId && (kartId == null || k.kartId == kartId);
        belge.kartlar.removeWhere((_, k) => eslesir(k));
        belge.taslaklar.removeWhere((_, k) => eslesir(k));
        await _depo.yaz(uid, belge.toJson(uid));
      });

  Future<_Belge> _belge(String uid) async {
    final d = await _depo.oku(uid);
    return d == null ? _Belge({}, {}) : _Belge.fromJson(uid, d);
  }

  static void _kapsam(String uid, String cariId, String kartId) {
    for (final v in [uid, cariId, kartId]) {
      if (!_metin(v)) throw _hata;
    }
  }

  // Web ile aynı ek doğrulama verisi; değiştirilirse eski kayıtlar açılmaz.
  static Uint8List _ekVeri(String uid, KartOzeti kart, String kimlik) =>
      utf8.encode(
        jsonEncode([
          'bup-pos-kart',
          1,
          uid,
          kart.cariId,
          kart.id,
          kart.sonDort,
          kart.ay,
          kart.yil,
          kimlik,
        ]),
      );

  static Uint8List _yuk(KartBilgileri b) => utf8.encode(
    jsonEncode({'numara': b.numara, 'sahibi': b.sahibi, 'telefon': b.telefon}),
  );

  static KartBilgileri _cozYuk(Uint8List duz, String sonDort) {
    final d = jsonDecode(utf8.decode(duz));
    if (d is! Map ||
        d.length != 3 ||
        d['numara'] is! String ||
        d['sahibi'] is! String ||
        d['telefon'] is! String) {
      throw _hata;
    }
    final KartBilgileri b;
    try {
      b = KartBilgileri(
        numara: d['numara'] as String,
        sahibi: d['sahibi'] as String,
        telefon: d['telefon'] as String,
      );
    } on PosHatasi {
      throw _hata;
    }
    // Kayıtlı değerler zaten düzenlenmiş olmalı; düzeltilerek kabul edilmez.
    if (b.numara != d['numara'] ||
        b.sahibi != d['sahibi'] ||
        b.telefon != d['telefon'] ||
        b.sonDort != sonDort) {
      throw _hata;
    }
    return b;
  }

  /// Açık metin baytları elden geldiğince bellekten silinir. Platform kanalından
  /// gelen dizi salt okunurdur; silinemezse sessizce geçilir (kriptografik
  /// silme iddiası yoktur, docs/CIHAZ_KART_KASASI.md).
  static void _sifirla(Uint8List b) {
    try {
      b.fillRange(0, b.length, 0);
    } on UnsupportedError {
      // Salt okunur görünüm.
    }
  }

  static String _etkin(String cariId, String kartId) =>
      jsonEncode([cariId, kartId]);

  static bool _metin(Object? v) =>
      v is String &&
      v.isNotEmpty &&
      v.length <= 128 &&
      !RegExp(r'[\x00-\x1f]').hasMatch(v);

  static String _rastgeleKimlik() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class _Kayit {
  _Kayit({
    required this.cariId,
    required this.kartId,
    required this.kimlik,
    required this.sonDort,
    required this.ay,
    required this.yil,
    required this.iv,
    required this.veri,
  });
  final String cariId, kartId, kimlik, sonDort;
  final int ay, yil;
  final Uint8List iv, veri;

  Map<String, Object> toJson() => {
    'cariId': cariId,
    'kartId': kartId,
    'kimlik': kimlik,
    'sonDort': sonDort,
    'ay': ay,
    'yil': yil,
    'iv': base64.encode(iv),
    'veri': base64.encode(veri),
  };

  static _Kayit fromJson(Object? d) {
    if (d is! Map ||
        d.length != 8 ||
        !SifreliKasa._metin(d['cariId']) ||
        !SifreliKasa._metin(d['kartId']) ||
        d['kimlik'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(d['kimlik'] as String) ||
        d['sonDort'] is! String ||
        !RegExp(r'^[0-9]{4}$').hasMatch(d['sonDort'] as String) ||
        d['ay'] is! int ||
        d['yil'] is! int ||
        d['iv'] is! String ||
        d['veri'] is! String) {
      throw SifreliKasa._hata;
    }
    final iv = base64.decode(d['iv'] as String);
    final veri = base64.decode(d['veri'] as String);
    if (iv.length != 12 || veri.length < 17) throw SifreliKasa._hata;
    return _Kayit(
      cariId: d['cariId'] as String,
      kartId: d['kartId'] as String,
      kimlik: d['kimlik'] as String,
      sonDort: d['sonDort'] as String,
      ay: d['ay'] as int,
      yil: d['yil'] as int,
      iv: iv,
      veri: veri,
    );
  }
}

class _Belge {
  _Belge(this.kartlar, this.taslaklar);
  final Map<String, _Kayit> kartlar, taslaklar;
  bool get bos => kartlar.isEmpty && taslaklar.isEmpty;

  Map<String, Object?> toJson(String uid) => {
    'v': 1,
    'uid': uid,
    'kartlar': {for (final e in kartlar.entries) e.key: e.value.toJson()},
    'taslaklar': {for (final e in taslaklar.entries) e.key: e.value.toJson()},
  };

  /// Başka kullanıcının, bozuk ya da tanınmayan belge hata verir; ezilmez.
  static _Belge fromJson(String uid, Map<String, Object?> d) {
    final k = d['kartlar'], t = d['taslaklar'];
    if (d.length != 4 || d['v'] != 1 || d['uid'] != uid || k is! Map) {
      throw SifreliKasa._hata;
    }
    if (t is! Map) throw SifreliKasa._hata;
    final kartlar = <String, _Kayit>{};
    for (final e in k.entries) {
      final kayit = _Kayit.fromJson(e.value);
      if (e.key != SifreliKasa._etkin(kayit.cariId, kayit.kartId)) {
        throw SifreliKasa._hata;
      }
      kartlar[e.key as String] = kayit;
    }
    final taslaklar = <String, _Kayit>{};
    for (final e in t.entries) {
      final kayit = _Kayit.fromJson(e.value);
      if (e.key != kayit.kimlik) throw SifreliKasa._hata;
      taslaklar[e.key as String] = kayit;
    }
    return _Belge(kartlar, taslaklar);
  }
}
