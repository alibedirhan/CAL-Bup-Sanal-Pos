import 'package:bup_sanal_pos/application/denizpay_oturumu.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/application/tahsilat_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/data/demo_islemleri.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/ui/pos_onayi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Android uygulama içi DenizPay geçişi: yapay depo, gerçek WebView yok.
// Kullanıcı isteği (27 Ekim): kart kaydı/seçimi olmadan da carinin DenizPay
// hesabına girilebilmeli; kart bilgileri o zaman DenizPay'de elle yazılır.
typedef Acilis = ({
  DenizPayBaglami baglam,
  Future<KartBilgileri?> Function() oku,
});

Future<(OturumModeli, DemoIslemDeposu, List<Acilis>)> hazirla(
  WidgetTester tester, {
  required bool kartSec,
}) async {
  final islemler = DemoIslemDeposu();
  final acilan = <Acilis>[];
  final model = OturumModeli(
    PosServisi(
      depo: DemoDeposu(),
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      uygulamaIciDenizPay: true,
      tahsilat: TahsilatServisi(
        depo: islemler,
        kullaniciId: DemoDeposu.kullanici,
        kullaniciAdi: 'Deneme Kullanıcısı',
      ),
    ),
    deneme: false,
    denizPayAcici: (context, baglam, kartiOku) async =>
        acilan.add((baglam: baglam, oku: kartiOku)),
  );
  addTearDown(model.dispose);
  await model.yukle();
  await model.profilAc('demo-cari-0');
  if (kartSec) model.kartSec(model.profil!.kartlar.first);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: PosOnayi(model: model)),
              ),
            ),
            child: const Text('onay'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('onay'));
  await tester.pumpAndSettle();
  return (model, islemler, acilan);
}

/// Android'de seçim kontrolü ve giriş tek adımdır: önce yalnız işaret kutusu.
Future<void> onayla(WidgetTester tester) async {
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  expect(find.text('Seçimi kontrol et'), findsNothing);
}

Future<void> girisYap(WidgetTester tester) async {
  final d = find.widgetWithText(FilledButton, 'DenizPay’e giriş yap');
  await tester.ensureVisible(d);
  await tester.tap(d);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Kart seçilmeden de carinin DenizPay hesabına girilir', (
    tester,
  ) async {
    final (model, islemler, acilan) = await hazirla(tester, kartSec: false);
    expect(model.otomatikGiris, isTrue);
    await onayla(tester);
    expect(
      find.textContaining(
        'Kart bilgilerini, CVV’yi ve tutarı DenizPay’de kendin yaz',
      ),
      findsOneWidget,
    );
    expect(find.text('DenizPay’i tarayıcıda aç (yedek)'), findsOneWidget);
    await girisYap(tester);
    final a = acilan.single;
    final cari = model.profil!.cari;
    expect(a.baglam.kart, isNull);
    expect(a.baglam.giris.vergiNo, cari.kimlikNo);
    expect(a.baglam.kayit.cariId, cari.id);
    expect(a.baglam.kayit.kartSonDort, '');
    expect(await a.oku(), isNull);
    // Giriş kaydı sunucuya (burada yapay depoya) yazıldı; ekran kapanınca onay penceresi de kapandı.
    final gun = await islemler.gun(Gun.ani(DateTime.now()));
    expect(gun.girisler.map((g) => g.id), contains(a.baglam.kayit.id));
    expect(find.text('onay'), findsOneWidget);
  });

  testWidgets('Kart seçilince bağlam kartı taşır ve kart sayfası anlatılır', (
    tester,
  ) async {
    final (model, _, acilan) = await hazirla(tester, kartSec: true);
    final kart = model.seciliKart!;
    await onayla(tester);
    expect(find.textContaining('“Kartı doldur”a bas'), findsOneWidget);
    await girisYap(tester);
    expect(acilan.single.baglam.kart?.id, kart.id);
    expect(acilan.single.baglam.kayit.kartSonDort, kart.sonDort);
  });

  testWidgets('Seçim kontrolünün süresi geçince ekran açılmaz', (tester) async {
    var simdi = DateTime(2026, 10, 27, 9);
    final acilan = <Object>[];
    final model = OturumModeli(
      PosServisi(
        depo: DemoDeposu(),
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
        uygulamaIciDenizPay: true,
        saat: () => simdi,
        tahsilat: TahsilatServisi(
          depo: DemoIslemDeposu(),
          kullaniciId: DemoDeposu.kullanici,
          kullaniciAdi: 'Deneme Kullanıcısı',
          saat: () => simdi,
        ),
      ),
      deneme: false,
      denizPayAcici: (_, b, _) async => acilan.add(b),
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc('demo-cari-0');
    // Arayüzde kontrol ve giriş tek dokunuştur; süre kuralı servis düzeyinde
    // (kontrol ile giriş arasında zaman geçerse, ör. hata ekranından dönüş).
    final sonuc = await model.dene();
    simdi = simdi.add(PosServisi.girisSuresi + const Duration(seconds: 1));
    expect(
      () => model.uygulamaIciGirisAc(sonuc!),
      throwsA(
        isA<PosHatasi>().having(
          (e) => e.mesaj,
          'mesaj',
          contains('süresi doldu'),
        ),
      ),
    );
    expect(acilan, isEmpty);
  });
}
