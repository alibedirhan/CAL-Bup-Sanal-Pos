import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../application/denizpay_oturumu.dart';
import '../../application/tahsilat_servisi.dart';
import '../../domain/bekleyen_sonuc.dart';
import 'kanal.dart';

/// Android'de uygulama içi DenizPay ekranının bıraktığı, henüz sunucuya
/// yazılmamış sonuçlar (web: `web/sonuc_kutusu.js`). Yedeğe girmeyen klasörde
/// tek JSON dosyası; uygulama kapanınca veya internet yokken kaybolmaz. Kart
/// bilgisi yoktur. Kurallar web ile aynı: en çok 20 sonuç, 30 gün, aynı kimlik
/// ikinci kez eklenmez, yalnız kutuyu işleyen servisin okuyabileceği kayıt
/// kabul edilir. Dosya ilk açılışta okunur; okununca [degisimler] tetiklenir.
class AndroidSonucKutusu implements SonucKutusu, SonucBirakmaPortu {
  AndroidSonucKutusu({
    Future<String> Function()? klasor,
    DateTime Function()? saat,
  }) : _klasor = klasor ?? yedeksizKlasor,
       _saat = saat ?? DateTime.now {
    _hazir = _yukle();
  }
  final Future<String> Function() _klasor;
  final DateTime Function() _saat;
  static const _sure = Duration(days: 30), _enFazla = 20;

  var _kayitlar = <Map<String, Object?>>[];
  late final Future<void> _hazir;
  Future<void> _yazma = Future.value();
  final _degisim = StreamController<void>.broadcast();
  final _yanit =
      StreamController<({String kimlik, bool tamam, String mesaj})>.broadcast();

  Future<File> get _dosya async => File('${await _klasor()}/sonuc-kutusu.json');

  Future<void> _yukle() async {
    final f = await _dosya;
    try {
      if (!await f.exists()) return;
      final d = jsonDecode(await f.readAsString());
      if (d is! List) throw const FormatException('kutu');
      _kayitlar = [
        for (final k in d)
          if (k is Map && _gecerli(k.cast<String, Object?>()))
            k.cast<String, Object?>(),
      ];
    } catch (_) {
      // Okunamayan dosya silinmez, ezilmez: elle incelemek için kenara alınır.
      try {
        await f.rename('${f.path}.bozuk');
      } catch (_) {}
    }
    if (_kayitlar.isNotEmpty) _degisim.add(null);
  }

  /// Kutuyu işleyen servisin okuyabildiği ve süresi dolmamış kayıt.
  bool _gecerli(Map<String, Object?> k) {
    final o = k['okunma'];
    if (o is! int) return false;
    final gecen = _saat().difference(DateTime.fromMillisecondsSinceEpoch(o));
    return gecen < _sure &&
        gecen > const Duration(minutes: -1) &&
        BekleyenSonuc.oku(k, 'Kontrol') != null;
  }

  static String? _kimlik(Map<String, Object?> k) {
    final b = BekleyenSonuc.oku(k, 'Kontrol');
    return b?.islem.kimlik;
  }

  Future<void> _kaydet() {
    final kopya = List.of(_kayitlar);
    _yazma = _yazma.then((_) async {
      final f = await _dosya;
      final gecici = File('${f.path}.yeni');
      await gecici.writeAsString(jsonEncode(kopya), flush: true);
      await gecici.rename(f.path);
    });
    return _yazma;
  }

  @override
  Future<String> birak(Map<String, Object?> kayit) async {
    await _hazir;
    if (kayit['v'] != 3 || !_gecerli(kayit)) {
      throw const FormatException('sonuc');
    }
    final kimlik = _kimlik(kayit);
    if (_kayitlar.any((k) => _kimlik(k) == kimlik)) return 'zaten';
    _kayitlar = [..._kayitlar, kayit];
    if (_kayitlar.length > _enFazla) {
      _kayitlar = _kayitlar.sublist(_kayitlar.length - _enFazla);
    }
    await _kaydet();
    _degisim.add(null);
    return 'ok';
  }

  @override
  bool get destekli => true;

  @override
  List<Map<String, Object?>> oku() => [
    for (final k in _kayitlar)
      if (_gecerli(k)) Map.of(k),
  ];

  @override
  void sil(String kimlik) {
    final once = _kayitlar.length;
    _kayitlar = [
      for (final k in _kayitlar)
        if (_kimlik(k) != kimlik) k,
    ];
    if (_kayitlar.length != once) unawaited(_kaydet().catchError((_) {}));
  }

  @override
  void yanitla(String kimlik, {required bool tamam, required String mesaj}) =>
      _yanit.add((kimlik: kimlik, tamam: tamam, mesaj: mesaj));

  @override
  Stream<void> get degisimler => _degisim.stream;

  @override
  Stream<({String kimlik, bool tamam, String mesaj})> get yanitlar =>
      _yanit.stream;

  /// Testler için: dosyadan okuma bitti.
  Future<void> get hazir => _hazir;
}
