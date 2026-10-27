import 'dart:convert';
import 'dart:io';
import 'package:bup_sanal_pos/application/biyometrik_kilit.dart';
import 'package:bup_sanal_pos/application/tahsilat_servisi.dart';
import 'package:bup_sanal_pos/data/android/biyometrik_kilit.dart';
import 'package:bup_sanal_pos/data/android/dosya_indirici.dart';
import 'package:bup_sanal_pos/data/android/kanal.dart';
import 'package:bup_sanal_pos/data/android/kart_kasasi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kotlin `GuvenlikKanali` taklidi: yalnız kanal sözleşmesini sınar. Gerçek
/// Keystore ve biyometri emülatördeki Android testlerindedir.
class SahteKanal {
  bool destekli = true;
  int acilis = 5;
  String dogrulama = 'tamam';
  final cagrilar = <String>[];
  final anahtarlar = <String>{};
  String? dosya;

  Future<Object?> isle(MethodCall c) async {
    cagrilar.add(c.method);
    final a = (c.arguments as Map?)?.cast<String, Object?>() ?? {};
    switch (c.method) {
      case 'biyo.durum':
        return {'destekli': destekli, 'acilis': acilis};
      case 'biyo.etkinlestir':
        anahtarlar.remove(a['uid']);
        if (!destekli) return false;
        anahtarlar.add(a['uid']! as String);
        return true;
      case 'biyo.sil':
        anahtarlar.remove(a['uid']);
        return null;
      case 'biyo.dogrula':
        return anahtarlar.contains(a['uid']) ? dogrulama : 'gecersiz';
      case 'dosya.kaydet':
        if (dosya == 'hata') {
          throw PlatformException(code: 'hata');
        }
        return dosya;
    }
    throw MissingPluginException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory klasor;
  late SahteKanal kanal;
  var simdi = DateTime.utc(2026, 10, 27, 9);
  setUp(() async {
    klasor = await Directory.systemTemp.createTemp('bup-android-');
    kanal = SahteKanal();
    simdi = DateTime.utc(2026, 10, 27, 9);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guvenlikKanali, kanal.isle);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guvenlikKanali, null);
    await klasor.delete(recursive: true);
  });

  AndroidBiyometrikKilit kilit() => AndroidBiyometrikKilit(
    saat: () => simdi,
    klasor: () async => klasor.path,
  );
  File kayitDosyasi() => File('${klasor.path}/biyometri.json');

  group('Biyometrik kilit', () {
    test('Şifre doğrulanmadan kullanılamaz; doğrulanınca açılır', () async {
      final k = kilit();
      expect(await k.kullanilabilir('u1'), isFalse);
      expect(await k.dogrula('u1'), BiyometriSonucu.sifreGerekli);
      await k.sifreDogrulandi('u1');
      expect(await k.kullanilabilir('u1'), isTrue);
      expect(await k.kullanilabilir('u2'), isFalse);
      expect(await k.dogrula('u1'), BiyometriSonucu.tamam);
      final d = jsonDecode(await kayitDosyasi().readAsString()) as Map;
      expect(d.keys.toSet(), {'v', 'uid', 'sonSifre', 'acilis'});
    });

    test('Yeniden başlatma ve 7 gün şifre ister', () async {
      final k = kilit();
      await k.sifreDogrulandi('u1');
      kanal.acilis = 6;
      expect(await k.kullanilabilir('u1'), isFalse);
      kanal.acilis = 5;
      simdi = simdi.add(const Duration(days: 7));
      expect(await k.dogrula('u1'), BiyometriSonucu.sifreGerekli);
      // Yeni şifre süreyi yeniler.
      await k.sifreDogrulandi('u1');
      expect(await k.kullanilabilir('u1'), isTrue);
    });

    test(
      'Yeni parmak izi (geçersiz anahtar) veya kilitlenme kaydı siler',
      () async {
        final k = kilit();
        for (final sonuc in ['gecersiz', 'kilit']) {
          await k.sifreDogrulandi('u1');
          kanal.dogrulama = sonuc;
          expect(await k.dogrula('u1'), BiyometriSonucu.sifreGerekli);
          expect(await kayitDosyasi().exists(), isFalse);
          expect(kanal.anahtarlar, isEmpty);
        }
        await k.sifreDogrulandi('u1');
        kanal.dogrulama = 'iptal';
        expect(await k.dogrula('u1'), BiyometriSonucu.iptal);
        expect(await k.kullanilabilir('u1'), isTrue);
      },
    );

    test('Biyometrisi olmayan telefonda kayıt tutulmaz', () async {
      kanal.destekli = false;
      final k = kilit();
      await k.sifreDogrulandi('u1');
      expect(await kayitDosyasi().exists(), isFalse);
      expect(await k.kullanilabilir('u1'), isFalse);
    });

    test(
      'Başka hesapla giriş öncekinin anahtarını siler; çıkış kaydı siler',
      () async {
        final k = kilit();
        await k.sifreDogrulandi('u1');
        await k.sifreDogrulandi('u2');
        expect(kanal.anahtarlar, {'u2'});
        expect(await k.kullanilabilir('u1'), isFalse);
        await k.unut('u1');
        expect(await k.kullanilabilir('u2'), isTrue);
        await k.unut('u2');
        expect(await k.kullanilabilir('u2'), isFalse);
        expect(kanal.anahtarlar, isEmpty);
      },
    );

    test('Bozuk kayıt biyometriyi kapatır, uygulamayı durdurmaz', () async {
      final k = kilit();
      await k.sifreDogrulandi('u1');
      await kayitDosyasi().writeAsString('{bozuk');
      expect(await k.kullanilabilir('u1'), isFalse);
      expect(await k.dogrula('u1'), BiyometriSonucu.sifreGerekli);
    });
  });

  group('Kasa dosyası', () {
    test('Yoksa boş; yazma atomik; bozuk dosya hata verir, ezilmez', () async {
      final d = DosyaKasaDeposu(klasor: () async => klasor.path);
      expect(await d.oku('kullanıcı/1'), isNull);
      await d.yaz('kullanıcı/1', {'v': 1, 'a': 'b'});
      expect(await d.oku('kullanıcı/1'), {'v': 1, 'a': 'b'});
      final dosyalar = Directory('${klasor.path}/kart-kasasi').listSync();
      expect(dosyalar, hasLength(1));
      expect(dosyalar.single.path.endsWith('.json'), isTrue);
      expect(dosyalar.single.path.contains('/kullan'), isFalse);
      final f = File(dosyalar.single.path);
      await f.writeAsString('[1]');
      await expectLater(d.oku('kullanıcı/1'), throwsFormatException);
      expect(await f.readAsString(), '[1]');
    });
  });

  group('Dosya kaydetme', () {
    test('Kaydedildi, vazgeçildi ve hata ayrı', () async {
      const i = AndroidDosyaIndirici();
      kanal.dosya = 'kaydedildi';
      expect(await i.indir('a.csv', 'x'), DosyaSonucu.kaydedildi);
      kanal.dosya = 'vazgecildi';
      expect(await i.indir('a.csv', 'x'), DosyaSonucu.vazgecildi);
      kanal.dosya = 'hata';
      await expectLater(
        i.indir('a.csv', 'x'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
