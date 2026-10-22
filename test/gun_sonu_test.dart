import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/app.dart';
import 'arayuz_test.dart' show tikla;

Future<void> baslat(WidgetTester tester, Size boyut) async {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(const BupPosApp());
  await tester.pumpAndSettle();
  await tikla(tester, find.text('Denemeyi aç'));
  await tester.pumpAndSettle();
}

Future<void> gunSonunuAc(WidgetTester tester) async {
  await tester.tap(find.text('Gün sonu'));
  await tester.pumpAndSettle();
}

void main() {
  for (final boyut in const [Size(375, 548), Size(320, 640), Size(1024, 800)]) {
    testWidgets('Gün sonu ${boyut.width.toInt()} px: toplam ve cariler', (
      tester,
    ) async {
      await baslat(tester, boyut);
      await gunSonunuAc(tester);
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.textContaining('Gün devam ediyor'), findsOneWidget);
      // Demo: Kuzey 4.500 (bir başarısız deneme ayrıca), Sahil 12.750,50.
      expect(find.text('17.250,50 TL'), findsOneWidget);
      expect(
        find.textContaining('2 cari · 2 başarılı · 1 başarısız'),
        findsOneWidget,
      );
      await tikla(tester, find.text('Örnek Kuzey Market'));
      expect(find.text('3D Şifresi Yanlış.'), findsOneWidget);
      // Bugünden ileri gidilmez.
      final ileri = find.widgetWithIcon(
        IconButton,
        Icons.chevron_right_rounded,
      );
      expect(tester.widget<IconButton>(ileri).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Önceki gün kapanmış ve boştur', (tester) async {
    await baslat(tester, const Size(390, 844));
    await gunSonunuAc(tester);
    await tester.tap(find.byTooltip('Önceki gün'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsNothing);
    expect(find.textContaining('Gün kapandı'), findsOneWidget);
    expect(find.text('Bu gün için kayıt yok'), findsOneWidget);
    expect(find.text('0,00 TL'), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki gün'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
  });

  testWidgets('Profilden elle kaydedilen sonuç gün sonuna eklenir', (
    tester,
  ) async {
    await baslat(tester, const Size(390, 844));
    await tikla(tester, find.text('Örnek Ada Market'));
    await tester.pumpAndSettle();
    await tikla(tester, find.text('Ödeme sonucunu elle kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Ödeme sonucunu kaydet'), findsOneWidget);
    final kaydet = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.ensureVisible(kaydet);
    await tester.pumpAndSettle();
    await tester.tap(kaydet);
    await tester.pumpAndSettle();
    expect(find.text('Tutarı DenizPay ekranındaki gibi yaz.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pos Sipariş Numarası'),
      'vp 4242 4242',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tutar'),
      '1.250,75',
    );
    await tester.pumpAndSettle();
    expect(find.text('1.250,75 TL'), findsOneWidget); // yazarken çevrilen tutar
    await tester.ensureVisible(kaydet);
    await tester.pumpAndSettle();
    await tester.tap(kaydet);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Kaydedildi: Örnek Ada Market · 1.250,75 TL'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Carilere dön'));
    await tester.pumpAndSettle();
    await gunSonunuAc(tester);
    expect(find.text('18.501,25 TL'), findsOneWidget);
    await tikla(tester, find.textContaining('Pos No VP42424242'));
    expect(find.textContaining('elle kaydedildi'), findsOneWidget);
  });
}
