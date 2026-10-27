import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/pin_kapisi.dart';
import 'package:bup_sanal_pos/data/android/kanal.dart';
import 'package:bup_sanal_pos/data/android/kart_kasasi.dart';
import 'package:bup_sanal_pos/data/kasa/sifreli_kasa.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/uygulama_pin.dart';
import 'package:bup_sanal_pos/ui/pin_penceresi.dart';

/// Kotlin `PinKasasi` taklidi: kanal çağrıları kaydedilir, yanıtlar sırayla verilir.
class _Kanal {
  _Kanal(this.durum, [this.dogrulama = const []]);
  Map<String, Object?> durum;
  final List<Map<String, Object?>> dogrulama;
  final cagrilar = <String>[];
  final pinler = <String>[];
  var _sira = 0;

  Future<Object?> yanit(MethodCall c) async {
    cagrilar.add(c.method);
    final a = (c.arguments as Map).cast<String, Object?>();
    if (a['pin'] case final String p) pinler.add(p);
    return switch (c.method) {
      'pin.durum' => durum,
      'pin.kur' => null,
      'pin.dogrula' => dogrulama[_sira++],
      'kasa.sifrele' => {'iv': Uint8List(12), 'veri': Uint8List(20)},
      'kasa.coz' => Uint8List.fromList([1, 2, 3]),
      _ => throw MissingPluginException(),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Yeni PIN: 6 rakam, tahmini kolay değil, iki kez aynı', () {
    expect(UygulamaPin.yeniPinHatasi('482915', '482915'), isNull);
    expect(UygulamaPin.yeniPinHatasi('48291', '48291'), contains('6 rakam'));
    expect(UygulamaPin.yeniPinHatasi('48291a', '48291a'), contains('6 rakam'));
    for (final kolay in ['111111', '123456', '654321', '012345']) {
      expect(UygulamaPin.yeniPinHatasi(kolay, kolay), contains('kolay'));
    }
    expect(UygulamaPin.yeniPinHatasi('482915', '482916'), contains('aynı'));
    expect(UygulamaPin.bicimli('000000'), isTrue);
    expect(UygulamaPin.bicimli('0000000'), isFalse);
  });

  group('Android kasa PIN akışı (kanal taklidi)', () {
    late _Kanal kanal;
    late List<PinIstegi> istekler;
    late List<String?> girisler;
    late PinKapisi kapi;
    final ek = Uint8List.fromList([9]);

    setUp(() {
      istekler = [];
      girisler = [];
      kapi = PinKapisi(kapat: () async {})
        ..baglan((i) async {
          istekler.add(i);
          return girisler.removeAt(0);
        });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(guvenlikKanali, null),
    );
    KeystoreSifreleyici hazirla(_Kanal k) {
      kanal = k;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(guvenlikKanali, k.yanit);
      return KeystoreSifreleyici(pin: kapi);
    }

    test('Telefon kilidi varsa PIN sorulmaz', () async {
      final s = hazirla(_Kanal({'mod': 'kilit', 'oturum': false}));
      await s.sifrele('u', ek, Uint8List(1), olustur: true);
      expect(istekler, isEmpty);
      expect(kanal.cagrilar, ['pin.durum', 'kasa.sifrele']);
    });

    test('Kilit yoksa ilk kartta PIN belirlenir, sonra şifrelenir', () async {
      final s = hazirla(_Kanal({'mod': 'kur', 'oturum': false}));
      girisler.add('482915');
      await s.sifrele('u', ek, Uint8List(1), olustur: true);
      expect(istekler.single.tur, PinTuru.kur);
      expect(kanal.cagrilar, ['pin.durum', 'pin.kur', 'kasa.sifrele']);
      expect(kanal.pinler, ['482915']);
    });

    test('Oturum açıksa PIN yeniden sorulmaz', () async {
      final s = hazirla(_Kanal({'mod': 'pin', 'oturum': true}));
      await s.coz('u', ek, SifreliVeri(Uint8List(12), Uint8List(20)));
      expect(istekler, isEmpty);
    });

    test('Yanlış PIN notla yeniden sorulur; doğruysa açılır', () async {
      final s = hazirla(
        _Kanal(
          {'mod': 'pin', 'oturum': false, 'kalan': 10, 'bekleme': 0},
          [
            {'sonuc': 'yanlis', 'kalan': 4, 'bekleme': 30000},
            {'sonuc': 'tamam'},
          ],
        ),
      );
      girisler.addAll(['000000', '482915']);
      final duz = await s.coz(
        'u',
        ek,
        SifreliVeri(Uint8List(12), Uint8List(20)),
      );
      expect(duz, [1, 2, 3]);
      expect(istekler.first.not, isNull);
      expect(istekler.last.not, contains('PIN yanlış.'));
      expect(istekler.last.not, contains('30 saniye'));
      expect(istekler.last.not, contains('Kalan deneme: 4'));
      expect(kanal.cagrilar.last, 'kasa.coz');
    });

    test('Vazgeçmek, silinme ve kaldırılmış kilit açıkça söylenir', () async {
      var s = hazirla(_Kanal({'mod': 'pin', 'oturum': false}));
      girisler.add(null);
      await expectLater(
        s.coz('u', ek, SifreliVeri(Uint8List(12), Uint8List(20))),
        throwsA(isA<PosHatasi>().having((e) => e.kod, 'kod', 'pin_iptal')),
      );
      expect(kanal.cagrilar, isNot(contains('kasa.coz')));

      s = hazirla(
        _Kanal(
          {'mod': 'pin', 'oturum': false},
          [
            {'sonuc': 'silindi'},
          ],
        ),
      );
      girisler.add('000000');
      await expectLater(
        s.coz('u', ek, SifreliVeri(Uint8List(12), Uint8List(20))),
        throwsA(isA<PosHatasi>().having((e) => e.kod, 'kod', 'pin_silindi')),
      );

      s = hazirla(_Kanal({'mod': 'kilit_kaldirildi', 'oturum': false}));
      await expectLater(
        s.sifrele('u', ek, Uint8List(1), olustur: false),
        throwsA(isA<PosHatasi>().having((e) => e.kod, 'kod', 'ekran_kilidi')),
      );
    });

    test(
      'Açık ekran yoksa PIN alınamaz; ayrılan ekran yenisini silmez',
      () async {
        Future<String?> yeni(PinIstegi _) async => '482915';
        Future<String?> eski(PinIstegi _) async => null;
        kapi
          ..baglan(yeni)
          ..ayir(eski);
        expect(await kapi.iste(const PinIstegi(PinTuru.gir)), '482915');
        kapi.ayir(yeni);
        expect(await kapi.iste(const PinIstegi(PinTuru.gir)), isNull);
      },
    );
  });

  Future<List<String?>> pencereAc(WidgetTester t, PinIstegi istek) async {
    final sonuc = <String?>[];
    await t.binding.setSurfaceSize(const Size(360, 800)); // Zebra TC15 (dp)
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => sonuc.add(await pinPenceresiAc(c, istek)),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    return sonuc;
  }

  Future<void> tusla(WidgetTester t, String pin) async {
    for (final r in pin.split('')) {
      await t.tap(find.byKey(ValueKey('pin-$r')));
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets(
    'PIN ekranı: yeni PIN yaz + tekrar; kolay ve uyuşmayan reddedilir',
    (t) async {
      final sonuc = await pencereAc(t, const PinIstegi(PinTuru.kur));
      expect(find.text('Yeni PIN belirle'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // sistem klavyesi açılmaz
      await tusla(t, '123456');
      expect(find.textContaining('kolay'), findsOneWidget);
      expect(find.text('Yeni PIN belirle'), findsOneWidget);
      await tusla(t, '482915');
      expect(find.text('Aynı PIN’i tekrar yaz'), findsOneWidget);
      await tusla(t, '482916');
      expect(find.textContaining('aynı değil'), findsOneWidget);
      expect(find.text('Yeni PIN belirle'), findsOneWidget);
      await tusla(t, '482915');
      await tusla(t, '482915');
      expect(sonuc, ['482915']);
    },
  );

  testWidgets('PIN ekranı: not görünür, silme çalışır, vazgeç null döner', (
    t,
  ) async {
    var sonuc = await pencereAc(
      t,
      const PinIstegi(PinTuru.gir, not: 'PIN yanlış. Kalan deneme: 4.'),
    );
    expect(find.text('PIN yanlış. Kalan deneme: 4.'), findsOneWidget);
    await tusla(t, '48');
    expect(find.bySemanticsLabel('2 / 6 rakam yazıldı'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pin-sil')));
    await t.pump();
    expect(find.bySemanticsLabel('1 / 6 rakam yazıldı'), findsOneWidget);
    await t.tap(find.byTooltip('Vazgeç'));
    await t.pumpAndSettle();
    expect(sonuc, [null]);

    sonuc = await pencereAc(t, const PinIstegi(PinTuru.gir));
    await tusla(t, '482915');
    expect(sonuc, ['482915']);
  });
}
