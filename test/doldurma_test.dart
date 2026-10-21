import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/portlar.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/domain/doldurma.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/ui/ana_ekran.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/pos_onayi.dart';
import 'pos_gecisi_test.dart' show SahteGirisKapisi, onayla;

// Kart sayfası yer iminin bekleyen işi yalnız yapay bellekte sınanır.
class SahteDoldurma implements DoldurmaHazirligi {
  final isler = <DoldurmaIsi>[];
  var temizlenme = 0;
  @override
  bool get destekli => true;
  @override
  void hazirla(DoldurmaIsi is_) => isler.add(is_);
  @override
  void temizle() => temizlenme++;
}

KartOzeti kasaKarti() => KartOzeti(
  id: 'kasa-kart',
  cariId: 'demo-cari-0',
  ad: 'Kasa kartı',
  sonDort: '1111',
  ay: 7,
  yil: DateTime.now().year + 2,
  cihazKayitId: 'kasa-referansi',
);

Future<OturumModeli> kur(
  WidgetTester tester, {
  required SahteGirisKapisi kapi,
  required SahteDoldurma doldurma,
  String? kartId,
  DateTime Function()? saat,
}) async {
  final depo = DemoDeposu();
  final p = await depo.profil(DemoDeposu.kullanici, 'demo-cari-0');
  await depo.kartKaydet(
    DemoDeposu.kullanici,
    'demo-cari-0',
    p.cari.surum,
    kasaKarti(),
  );
  final model = OturumModeli(
    PosServisi(
      depo: depo,
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      girisKapisi: kapi,
      doldurma: doldurma,
      saat: saat,
    ),
    deneme: false,
  );
  addTearDown(model.dispose);
  await model.yukle();
  await model.profilAc('demo-cari-0');
  if (kartId != null) {
    model.kartSec(model.profil!.kartlar.singleWhere((k) => k.id == kartId));
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PosOnayi(model: model)),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

Future<void> girisYap(WidgetTester tester) async {
  final giris = find.widgetWithText(FilledButton, 'DenizPay’e giriş yap');
  await tester.ensureVisible(giris);
  await tester.tap(giris);
  await tester.pumpAndSettle();
}

void main() {
  test('Bekleyen iş yalnız kasa referansı taşır; tutar/CVV/numara yok', () {
    final son = DateTime(2030, 1, 1, 9, 10);
    final json = DoldurmaIsi(
      kullaniciId: 'u1',
      kart: kasaKarti(),
      kimlikNo: '0000000001',
      son: son,
    ).toJson();
    expect(json.keys, unorderedEquals(['v', 'uid', 'kimlikNo', 'son', 'kart']));
    expect(
      (json['kart'] as Map).keys,
      unorderedEquals(['id', 'cariId', 'sonDort', 'ay', 'yil', 'cihazKayitId']),
    );
    expect(json['son'], son.millisecondsSinceEpoch);
    final metin = json.toString().toLowerCase();
    for (final yok in ['numara', 'cvv', 'cvc', 'tutar', 'sifre', 'otp']) {
      expect(metin, isNot(contains(yok)));
    }
    expect(DoldurmaIsi.sure, const Duration(minutes: 10));
  });

  test('Kasa referansı olmayan kart veya geçersiz kimlik için iş kurulmaz', () {
    final demo = KartOzeti(
      id: 'k',
      cariId: 'c',
      ad: 'Kart',
      sonDort: '0001',
      ay: 1,
      yil: 2099,
    );
    for (final (kart, kimlik) in [(demo, '0000000001'), (kasaKarti(), '12')]) {
      expect(
        () => DoldurmaIsi(
          kullaniciId: 'u1',
          kart: kart,
          kimlikNo: kimlik,
          son: DateTime(2030),
        ),
        throwsA(isA<PosHatasi>()),
      );
    }
  });

  testWidgets('Kartla girişte seçili kartın işi 10 dakikalık hazırlanır', (
    tester,
  ) async {
    final kapi = SahteGirisKapisi(), doldurma = SahteDoldurma();
    final simdi = DateTime.now();
    await kur(
      tester,
      kapi: kapi,
      doldurma: doldurma,
      kartId: 'kasa-kart',
      saat: () => simdi,
    );
    await onayla(tester);
    expect(doldurma.isler, isEmpty);
    await girisYap(tester);
    expect(kapi.girisler, hasLength(1));
    final is_ = doldurma.isler.single;
    expect(is_.kart.id, 'kasa-kart');
    expect(is_.kart.cihazKayitId, 'kasa-referansi');
    expect(is_.kimlikNo, '0000000001');
    expect(is_.kullaniciId, DemoDeposu.kullanici);
    expect(is_.son, simdi.add(DoldurmaIsi.sure));
    expect(find.textContaining('BUP Doldur'), findsOneWidget);
  });

  testWidgets('Kartsız giriş cariyle açılır, eski kart işini siler', (
    tester,
  ) async {
    final kapi = SahteGirisKapisi(), doldurma = SahteDoldurma();
    await kur(tester, kapi: kapi, doldurma: doldurma);
    expect(find.textContaining('Seçilmedi'), findsOneWidget);
    await onayla(tester);
    final once = doldurma.temizlenme;
    await girisYap(tester);
    expect(kapi.girisler.single.kullanici, '0000000001');
    expect(doldurma.isler, isEmpty);
    expect(doldurma.temizlenme, greaterThan(once));
    expect(find.textContaining('BUP Doldur'), findsNothing);
  });

  testWidgets('Kasa referansı olmayan kartla giriş açılır, iş kurulmaz', (
    tester,
  ) async {
    final kapi = SahteGirisKapisi(), doldurma = SahteDoldurma();
    await kur(tester, kapi: kapi, doldurma: doldurma, kartId: 'demo-kart-0');
    await onayla(tester);
    await girisYap(tester);
    expect(kapi.girisler, hasLength(1));
    expect(doldurma.isler, isEmpty);
  });

  testWidgets('Ekran kilidi bekleyen kart işini siler', (tester) async {
    final kapi = SahteGirisKapisi(), doldurma = SahteDoldurma();
    final model = await kur(
      tester,
      kapi: kapi,
      doldurma: doldurma,
      kartId: 'kasa-kart',
    );
    await onayla(tester);
    await girisYap(tester);
    final once = doldurma.temizlenme;
    model.kilitle();
    expect(doldurma.temizlenme, once + 1);
  });

  testWidgets('Kart seçilmeden ödeme sitesine geçiş düğmesi açıktır', (
    tester,
  ) async {
    final model = OturumModeli(
      PosServisi(
        depo: DemoDeposu(),
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
        girisKapisi: SahteGirisKapisi(),
      ),
      deneme: false,
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc('demo-cari-5');
    expect(model.profil!.kartlar, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: AnaEkran(model: model, kilitle: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kart seçmeden de DenizPay’e girebilirsin.'), findsOne);
    final gec = find.widgetWithText(FilledButton, 'Ödeme sitesine geç');
    expect(tester.widget<FilledButton>(gec).onPressed, isNotNull);
    await tester.tap(gec);
    await tester.pumpAndSettle();
    expect(find.byType(PosOnayi), findsOneWidget);
  });

  testWidgets('Deneme kipinde kartsız geçiş yoktur', (tester) async {
    final model = OturumModeli(
      PosServisi(
        depo: DemoDeposu(),
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
        girisKapisi: SahteGirisKapisi(),
      ),
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc('demo-cari-0');
    expect(model.otomatikGiris, isFalse);
    expect(await model.dene(), isNull);
  });
}
