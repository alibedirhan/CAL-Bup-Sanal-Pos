import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../domain/hata.dart';
import '../kasa/sifreli_kasa.dart';
import 'kanal.dart';

/// Android Keystore şifrelemesi (`KasaAnahtari.kt`): kullanıcı başına dışa
/// aktarılamaz AES-256-GCM anahtarı, yalnız telefon kilidi açıkken.
class KeystoreSifreleyici implements KasaSifreleyici {
  const KeystoreSifreleyici();

  static const _kilitYok = PosHatasi(
    'ekran_kilidi',
    'Kartın tam bilgisini saklamak ve açmak için telefonda ekran kilidi '
        '(PIN, desen veya parmak izi) açık olmalı.',
  );

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
  Future<Uint8List> coz(String uid, Uint8List ekVeri, SifreliVeri v) =>
      _cagir<Uint8List>('kasa.coz', {
        'uid': uid,
        'ekVeri': ekVeri,
        'iv': v.iv,
        'veri': v.veri,
      });
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
