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

  testWidgets('Pencere: yeni PIN iki kez ve kurala göre alınır', (t) async {
    String? sonuc = 'yok';
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async =>
                sonuc = await pinPenceresiAc(c, const PinIstegi(PinTuru.kur)),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.text('Uygulama PIN’i belirle'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await t.enterText(find.widgetWithText(TextField, 'PIN (tekrar)'), '123456');
    await t.tap(find.text('PIN’i kaydet'));
    await t.pump();
    expect(find.textContaining('kolay'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'PIN'), '48a2915');
    expect(
      t
          .widget<TextField>(find.widgetWithText(TextField, 'PIN'))
          .controller!
          .text,
      '482915',
    );
    await t.enterText(find.widgetWithText(TextField, 'PIN (tekrar)'), '482915');
    await t.tap(find.text('PIN’i kaydet'));
    await t.pumpAndSettle();
    expect(sonuc, '482915');
  });

  testWidgets('Pencere: önceki denemenin notu görünür, vazgeç null döner', (
    t,
  ) async {
    String? sonuc = 'yok';
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => sonuc = await pinPenceresiAc(
              c,
              const PinIstegi(PinTuru.gir, not: 'PIN yanlış. Kalan deneme: 4.'),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.text('PIN yanlış. Kalan deneme: 4.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'PIN (tekrar)'), findsNothing);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(sonuc, isNull);
  });
}
