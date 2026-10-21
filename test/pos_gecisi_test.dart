import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/pos_onayi.dart';

// Canlı ekran davranışı, tamamen yapay bellek deposuyla sınanır.
// Bağlantıya tıklanmaz; gerçek ödeme sitesine hiçbir istek yapılmaz.
Future<OturumModeli> hazirla(WidgetTester tester) async {
  final model = OturumModeli(
    PosServisi(
      depo: DemoDeposu(),
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
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
}
