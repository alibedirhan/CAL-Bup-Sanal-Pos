import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';
import 'package:bup_sanal_pos/application/portlar.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/domain/pos_girisi.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/pos_onayi.dart';

// Canlı ekran davranışı, tamamen yapay bellek deposuyla sınanır.
// Bağlantıya tıklanmaz; gerçek ödeme sitesine hiçbir istek yapılmaz.
/// Giriş bilgisini yalnız bellekte tutar; formu gönderen tarayıcı bağdaştırıcısı yerine.
class SahteGirisKapisi implements PosGirisKapisi {
  final girisler = <PosGirisBilgisi>[];
  @override
  bool get destekli => true;
  @override
  void ac(PosGirisBilgisi giris) => girisler.add(giris);
}

Future<OturumModeli> hazirla(
  WidgetTester tester, {
  PosGirisKapisi girisKapisi = const KapaliPosGirisKapisi(),
  DateTime Function()? saat,
}) async {
  final model = OturumModeli(
    PosServisi(
      depo: DemoDeposu(),
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      girisKapisi: girisKapisi,
      saat: saat,
    ),
    deneme: false,
  );
  addTearDown(model.dispose);
  await model.yukle();
  await model.profilAc('demo-cari-0');
  model.kartSec(model.profil!.kartlar.first);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PosOnayi(model: model)),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

Future<void> onayla(WidgetTester tester) async {
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  final dugme = find.widgetWithText(FilledButton, 'Seçimi kontrol et');
  await tester.ensureVisible(dugme);
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Doğrulanan seçim doğrudan, verisiz DenizPay bağlantısı sunar', (
    tester,
  ) async {
    await hazirla(tester);
    expect(find.byType(Link), findsNothing);
    await onayla(tester);
    final link = tester.widget<Link>(find.byType(Link));
    expect(link.uri.toString(), 'https://denizpay.bupilic.com.tr/login.aspx');
    expect(link.target, LinkTarget.blank);
    expect(link.uri!.hasQuery, isFalse);
    expect(link.uri!.hasFragment, isFalse);
    expect(link.uri!.userInfo, isEmpty);
    expect(find.text('DenizPay ödeme girişini aç'), findsOneWidget);
    expect(
      find.textContaining('Seçili kart otomatik aktarılmaz'),
      findsOneWidget,
    );
    expect(find.text('Bupiliç sitesini aç'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sunucudan doğrulanamayan seçim ödeme bağlantısını açmaz', (
    tester,
  ) async {
    final model = await hazirla(tester);
    final cari = model.profil!.cari;
    await model.servis.depo.sil(DemoDeposu.kullanici, cari.id, cari.surum);
    await onayla(tester);
    expect(find.byType(Link), findsNothing);
    expect(find.textContaining('Cari bulunamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Otomatik giriş yalnız düğmeyle, seçili carinin bilgisiyle', (
    tester,
  ) async {
    final kapi = SahteGirisKapisi();
    await hazirla(tester, girisKapisi: kapi);
    await onayla(tester);
    // Seçim kontrolü tek başına giriş bilgisi göndermez.
    expect(kapi.girisler, isEmpty);
    expect(find.text('Boş giriş sayfasını aç'), findsOneWidget);
    expect(
      find.textContaining('Seçili kart otomatik aktarılmaz'),
      findsNothing,
    );
    final giris = find.widgetWithText(FilledButton, 'DenizPay’e giriş yap');
    await tester.ensureVisible(giris);
    await tester.tap(giris);
    await tester.pumpAndSettle();
    expect(kapi.girisler, hasLength(1));
    final g = kapi.girisler.single;
    expect(
      [g.vergiNo, g.kullanici, g.sifre],
      ['0000000001', '0000000001', '0001'],
    );
    expect(g.toString(), isNot(contains('0001')));
    expect(find.textContaining('DenizPay yeni sekmede açıldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Süresi geçen kontrol girişi açmaz, yeniden kontrol ister', (
    tester,
  ) async {
    final kapi = SahteGirisKapisi();
    var simdi = DateTime.now();
    await hazirla(tester, girisKapisi: kapi, saat: () => simdi);
    await onayla(tester);
    simdi = simdi.add(PosServisi.girisSuresi + const Duration(seconds: 1));
    final giris = find.widgetWithText(FilledButton, 'DenizPay’e giriş yap');
    await tester.ensureVisible(giris);
    await tester.tap(giris);
    await tester.pumpAndSettle();
    expect(kapi.girisler, isEmpty);
    expect(find.textContaining('süresi doldu'), findsOneWidget);
  });

  testWidgets('Kilitlenen ekranda giriş bilgisi gönderilmez', (tester) async {
    final kapi = SahteGirisKapisi();
    final model = await hazirla(tester, girisKapisi: kapi);
    await onayla(tester);
    model.kilitle();
    await tester.pumpAndSettle();
    final giris = find.widgetWithText(FilledButton, 'DenizPay’e giriş yap');
    if (giris.evaluate().isNotEmpty) {
      await tester.ensureVisible(giris);
      await tester.tap(giris);
      await tester.pumpAndSettle();
    }
    expect(kapi.girisler, isEmpty);
  });
}
