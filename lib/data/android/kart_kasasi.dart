import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../application/pin_kapisi.dart';
import '../../domain/hata.dart';
import '../kasa/sifreli_kasa.dart';
import 'kanal.dart';

/// Android Keystore şifrelemesi (`KasaAnahtari.kt`): kullanıcı başına dışa
/// aktarılamaz AES-256-GCM anahtarı, yalnız telefon kilidi açıkken. Telefonda
/// ekran kilidi yoksa kasa uygulama PIN'iyle korunur (`PinKasasi.kt`): PIN
/// [pin] kapısından sorulur, doğrulama ve deneme sınırı Kotlin'dedir.
class KeystoreSifreleyici implements KasaSifreleyici {
  const KeystoreSifreleyici({this.pin});
  final PinKapisi? pin;

  static const _kilitYok = PosHatasi(
    'ekran_kilidi',
    'Kartın tam bilgisini saklamak ve açmak için telefonda ekran kilidi '
        '(PIN, desen veya parmak izi) açık olmalı.',
  );

  static const _kilitKaldirildi = PosHatasi(
    'ekran_kilidi',
    'Bu telefondaki kartlar ekran kilidiyle korunuyordu ve kilit kaldırılmış. '
        'Ekran kilidini yeniden aç ya da kartları silip yeniden ekle.',
  );
  static const _iptal = PosHatasi(
    'pin_iptal',
    'PIN girilmedi; kart bilgisi açılmadı.',
  );
  static const _silindi = PosHatasi(
    'pin_silindi',
    '10 kez yanlış PIN girildi. Güvenlik için bu telefondaki kart bilgileri '
        'silindi; kartları yeniden ekle.',
  );

  /// Kasa telefon kilidiyle mi PIN'le mi korunuyor; PIN gerekiyorsa sorar.
  /// [olustur]: kasa boş, ilk kart (kilit yoksa yeni PIN belirlenir).
  Future<void> _pinHazirla(String uid, {required bool olustur}) async {
    final d = await _cagir<Map<Object?, Object?>>('pin.durum', {'uid': uid});
    switch (d['mod']) {
      case 'kilit_kaldirildi':
        throw _kilitKaldirildi;
      case 'kur' when olustur:
        final yeni = await pin?.iste(const PinIstegi(PinTuru.kur));
        if (yeni == null) throw _iptal;
        // Değer döndürmez (Kotlin Unit → null); boş yanıt hata sayılmaz.
        await guvenlikKanali.invokeMethod<void>('pin.kur', {
          'uid': uid,
          'pin': yeni,
        });
      case 'pin' when d['oturum'] != true:
        String? not = _not(d['kalan'], d['bekleme']);
        while (true) {
          final girilen = await pin?.iste(PinIstegi(PinTuru.gir, not: not));
          if (girilen == null) throw _iptal;
          final r = await _cagir<Map<Object?, Object?>>('pin.dogrula', {
            'uid': uid,
            'pin': girilen,
          });
          switch (r['sonuc']) {
            case 'tamam':
              return;
            case 'silindi':
              throw _silindi;
            case 'yanlis' || 'bekle':
              not = r['sonuc'] == 'yanlis' ? 'PIN yanlış.' : null;
              not = [?not, ?_not(r['kalan'], r['bekleme'])].join(' ');
            default:
              throw StateError('pin');
          }
        }
    }
  }

  /// Kalan deneme ve bekleme notu; söylenecek yoksa `null`.
  static String? _not(Object? kalan, Object? bekleme) {
    final parcalar = <String>[
      if (bekleme is int && bekleme > 0)
        '${(bekleme / 1000).ceil()} saniye sonra yeniden dene.',
      if (kalan is int && kalan <= 5)
        'Kalan deneme: $kalan. Hakkın bitince bu telefondaki kart bilgileri silinir.',
    ];
    return parcalar.isEmpty ? null : parcalar.join(' ');
  }

  Future<T> _cagir<T>(String yontem, Map<String, Object> d) async {
    try {
      final r = await guvenlikKanali.invokeMethod<T>(yontem, d);
      return r ?? (throw StateError(yontem));
    } on PlatformException catch (e) {
      if (e.code == 'ekran_kilidi') throw _kilitYok;
      rethrow;
    }
  }

  @override
  Future<SifreliVeri> sifrele(
    String uid,
    Uint8List ekVeri,
    Uint8List duz, {
    required bool olustur,
  }) async {
    await _pinHazirla(uid, olustur: olustur);
    final r = await _cagir<Map<Object?, Object?>>('kasa.sifrele', {
      'uid': uid,
      'ekVeri': ekVeri,
      'duz': duz,
      'olustur': olustur,
    });
    final iv = r['iv'], veri = r['veri'];
    if (iv is! Uint8List || veri is! Uint8List) throw StateError('sifrele');
    return SifreliVeri(iv, veri);
  }

  @override
  Future<Uint8List> coz(String uid, Uint8List ekVeri, SifreliVeri v) async {
    await _pinHazirla(uid, olustur: false);
    return _cagir<Uint8List>('kasa.coz', {
      'uid': uid,
      'ekVeri': ekVeri,
      'iv': v.iv,
      'veri': v.veri,
    });
  }
}

/// Kullanıcı başına bir JSON belgesi, yedeğe girmeyen klasörde. Yazma önce
/// geçici dosyaya, sonra aynı klasörde yeniden adlandırma: belge ya eski ya
/// yeni hâliyle kalır, yarım yazılmaz.
class DosyaKasaDeposu implements KasaDeposu {
  DosyaKasaDeposu({Future<String> Function()? klasor})
    : _klasor = klasor ?? yedeksizKlasor;
  final Future<String> Function() _klasor;

  Future<File> _dosya(String uid) async {
    final k = Directory('${await _klasor()}/kart-kasasi');
    await k.create(recursive: true);
    // Dosya adı için güvenli karakterler (base64url); kimliği gizlemek için değil.
    final ad = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return File('${k.path}/$ad.json');
  }

  @override
  Future<Map<String, Object?>?> oku(String uid) async {
    final f = await _dosya(uid);
    if (!await f.exists()) return null;
    final d = jsonDecode(await f.readAsString());
    if (d is! Map) throw const FormatException('kasa');
    return d.cast<String, Object?>();
  }

  @override
  Future<void> yaz(String uid, Map<String, Object?> belge) async {
    final f = await _dosya(uid);
    final gecici = File('${f.path}.yeni');
    await gecici.writeAsString(jsonEncode(belge), flush: true);
    await gecici.rename(f.path);
  }
}
