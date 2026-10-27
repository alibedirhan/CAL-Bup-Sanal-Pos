import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/kart_tarama.dart';
import 'package:bup_sanal_pos/data/android/nfc_okuyucu.dart';
import 'package:bup_sanal_pos/domain/kart_okuma.dart';
import 'package:bup_sanal_pos/ui/kart_okuma_kutusu.dart';
import 'package:bup_sanal_pos/ui/kart_tarama_ekrani.dart';

const pan = '5555555555554444';

class _Oturum implements KartTaramaOturumu {
  final kontrol = StreamController<TaramaOlayi>.broadcast();
  int baslama = 0, kapanma = 0, ayar = 0;
  @override
  Stream<TaramaOlayi> get olaylar => kontrol.stream;
  @override
  Future<void> baslat() async => baslama++;
  @override
  Future<void> kapat() async => kapanma++;
  @override
  Future<void> ayarlariAc() async => ayar++;
}

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
Uint8List bayt(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kamera kareleri', () {
    const a = OkunanKart(numara: pan);
    test('Numara iki karede aynı okununca; tarih sonradan da gelebilir', () {
      final b = KareBirlestirici();
      expect(b.ekle(a), isNull);
      expect(b.ekle(const OkunanKart(ay: 8, yil: 2031)), isNull);
      final k = b.ekle(a)!;
      expect((k.numara, k.ay, k.yil), (pan, 8, 2031));
    });
    test('Farklı numara sayacı sıfırlar; tek kare yetmez', () {
      final b = KareBirlestirici(tarihBekleme: 0);
      expect(b.ekle(a), isNull);
      expect(b.ekle(const OkunanKart(numara: '4111111111111111')), isNull);
      expect(b.ekle(a), isNull);
      expect(b.ekle(a)?.numara, pan);
    });
    test('Tarih hiç okunmazsa birkaç kare beklenir, sonra tarihsiz döner', () {
      final b = KareBirlestirici(tarihBekleme: 2);
      expect(b.ekle(a), isNull);
      expect(b.ekle(a), isNull);
      expect(b.tarihAraniyor, isTrue);
      expect(b.ekle(const OkunanKart()), isNull);
      final k = b.ekle(const OkunanKart())!;
      expect((k.numara, k.ay), (pan, null));
    });
  });

  group('Okuma ekranı', () {
    Future<List<Object?>> ac(WidgetTester t, _Oturum o) async {
      final sonuc = <Object?>[];
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async => sonuc.add(
                await Navigator.of(c).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        KartTaramaEkrani(tur: TaramaTuru.nfc, oturum: o),
                  ),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      return sonuc;
    }

    testWidgets(
      'Durum, ayarlar düğmesi; okununca kartla kapanır, donanım bırakılır',
      (t) async {
        final o = _Oturum();
        final sonuc = await ac(t, o);
        expect(o.baslama, 1);
        o.kontrol.add(
          const TaramaNotu('NFC kapalı.', hata: true, ayarlar: true),
        );
        await t.pump();
        await t.pumpAndSettle();
        expect(find.text('NFC kapalı.'), findsOneWidget);
        await t.tap(find.text('Ayarları aç'));
        expect(o.ayar, 1);
        // Ayarlardan dönünce yeniden başlatılır.
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pump();
        expect(o.baslama, 2);
        expect(find.textContaining('CVV okunmaz'), findsOneWidget);
        o.kontrol.add(const TaramaOkundu(OkunanKart(numara: pan)));
        await t.pumpAndSettle();
        expect(find.byType(KartTaramaEkrani), findsNothing);
        expect(o.kapanma, 1);
        expect((sonuc.single as OkunanKart?)?.numara, pan);
      },
    );

    testWidgets('Vazgeç: sonuç yok, donanım bırakılır', (t) async {
      final o = _Oturum();
      final sonuc = await ac(t, o);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(o.kapanma, 1);
      expect(sonuc, [null]);
    });
  });

  testWidgets('Form kutusu: yalnız cihazdaki yollar; okunan forma yazılır', (
    t,
  ) async {
    final okunan = <OkunanKart>[];
    final istenen = <TaramaTuru>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KartOkumaKutusu(
            etkin: true,
            simdi: () => DateTime(2026, 10, 27),
            okundu: okunan.add,
            tarayici: KartTarayicilari(
              turler: () async => {TaramaTuru.nfc},
              ac: (_, tur) async {
                istenen.add(tur);
                return const OkunanKart(numara: pan, ay: 8, yil: 2031);
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Temassız oku'), findsOneWidget);
    expect(find.text('Kamerayla oku'), findsNothing);
    await t.tap(find.text('Temassız oku'));
    await t.pumpAndSettle();
    expect(istenen, [TaramaTuru.nfc]);
    expect(okunan.single.numara, pan);
    expect(find.textContaining('•••• 4444 · 08 / 2031'), findsOneWidget);
    expect(find.textContaining('kart üzerindeki ad'), findsOneWidget);
  });

  group('NFC okuyucu (kanal taklidi)', () {
    const kanal = MethodChannel('bup/nfc');
    final mesajci =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> cagrilar;
    late Map<String, Object?> durum;
    late bool kartCekildi;

    setUp(() {
      cagrilar = [];
      durum = {'var': true, 'acik': true};
      kartCekildi = false;
      mesajci.setMockMethodCallHandler(kanal, (c) async {
        cagrilar.add(c.method);
        if (c.method == 'durum') return durum;
        if (c.method != 'apdu') return null;
        if (kartCekildi) throw PlatformException(code: 'kart_ayrildi');
        final h = hex((c.arguments as Map)['komut'] as Uint8List);
        // Dizinsiz yapay Mastercard: seçim → GPO biçim 2 → numara ve tarih.
        if (h.startsWith('00A4040007A0000000041010')) return bayt('6F009000');
        if (h.startsWith('80A8')) {
          return bayt(
            '77'
            '10'
            '5A08$pan'
            '5F2403310831'
            '9000',
          );
        }
        return bayt('6A82');
      });
    });
    tearDown(() => mesajci.setMockMethodCallHandler(kanal, null));

    Future<void> kartDokundu() => mesajci.handlePlatformMessage(
      'bup/nfc',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('kart')),
      (_) {},
    );

    test(
      'NFC yok veya kapalı: söylenir; kapalıysa ayarlara yönlendirilir',
      () async {
        durum = {'var': false, 'acik': false};
        var o = NfcOkuyucu(saat: () => DateTime(2026, 10, 27));
        var olay = o.olaylar.first;
        await o.baslat();
        expect(((await olay) as TaramaNotu).ayarlar, isFalse);
        durum = {'var': true, 'acik': false};
        o = NfcOkuyucu(saat: () => DateTime(2026, 10, 27));
        olay = o.olaylar.first;
        await o.baslat();
        expect(((await olay) as TaramaNotu).ayarlar, isTrue);
        expect(cagrilar, isNot(contains('baslat')));
      },
    );

    test('Kart dokununca okunur; kapatınca okuyucu kipi kapanır', () async {
      final o = NfcOkuyucu(saat: () => DateTime(2026, 10, 27));
      final olaylar = <TaramaOlayi>[];
      o.olaylar.listen(olaylar.add);
      await o.baslat();
      expect(cagrilar, ['durum', 'baslat']);
      await kartDokundu();
      await pumpEventQueue();
      final k = olaylar.whereType<TaramaOkundu>().single.kart;
      expect((k.numara, k.ay, k.yil), (pan, 8, 2031));
      await o.kapat();
      expect(cagrilar.last, 'bitir');
    });

    test('Kart erken çekilirse söylenir, yeniden denenebilir', () async {
      final o = NfcOkuyucu(saat: () => DateTime(2026, 10, 27));
      final olaylar = <TaramaOlayi>[];
      o.olaylar.listen(olaylar.add);
      await o.baslat();
      kartCekildi = true;
      await kartDokundu();
      await pumpEventQueue();
      expect(
        olaylar.whereType<TaramaNotu>().last.mesaj,
        contains('erken çekildi'),
      );
      kartCekildi = false;
      await kartDokundu();
      await pumpEventQueue();
      expect(olaylar.whereType<TaramaOkundu>(), hasLength(1));
      await o.kapat();
    });
  });
}
