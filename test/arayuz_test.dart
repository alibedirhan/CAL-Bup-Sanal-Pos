import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/app.dart';
import 'package:bup_sanal_pos/ui/kart_kutusu.dart';

Future<void> baslat(
  WidgetTester tester, {
  double genislik = 390,
  double olcek = 1,
}) async {
  tester.view.physicalSize = Size(genislik, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = olcek;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(const BupPosApp());
  await tester.pumpAndSettle();
  await tikla(tester, find.text('Denemeyi aç'));
  await tester.pumpAndSettle();
}

Future<void> tikla(WidgetTester tester, Finder hedef) async {
  if (hedef.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      hedef,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
  }
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
}

void main() {
  testWidgets('Cari arama ve boş sonuçtan geri dönüş çalışır', (tester) async {
    await baslat(tester);
    await tester.enterText(find.byType(TextField), 'kuzey');
    await tester.pumpAndSettle();
    expect(find.text('Örnek Kuzey Market'), findsOneWidget);
    expect(find.text('Örnek Sahil Gıda'), findsNothing);
    await tester.enterText(find.byType(TextField), 'bulunmayan');
    await tester.pumpAndSettle();
    expect(find.text('Cari bulunamadı'), findsOneWidget);
    await tikla(tester, find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Örnek Kuzey Market'), findsOneWidget);
  });
  testWidgets('Kart seçimi ve açık onay olmadan geçiş yapılamaz', (
    tester,
  ) async {
    await baslat(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    final devam = find.widgetWithText(FilledButton, 'POS’a geçişi dene');
    expect(tester.widget<FilledButton>(devam).onPressed, isNull);
    await tikla(tester, find.byType(KartKutusu).first);
    await tester.pumpAndSettle();
    await tikla(tester, devam);
    await tester.pumpAndSettle();
    final dene = find.widgetWithText(FilledButton, 'Geçişi dene');
    expect(tester.widget<FilledButton>(dene).onPressed, isNull);
    await tikla(tester, find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tikla(tester, dene);
    await tester.pumpAndSettle();
    expect(find.text('Geçiş denemesi tamamlandı'), findsOneWidget);
    expect(find.textContaining('Gerçek POS açılmadı'), findsOneWidget);
  });
  testWidgets('Yeni cari kod istemez, kimlik numarasıyla eklenir', (
    tester,
  ) async {
    await baslat(tester);
    await tikla(tester, find.text('Yeni cari'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Örnek Yeni Cari');
    expect(find.text('Cari kodu'), findsNothing);
    await tester.enterText(find.byType(TextFormField).last, '0000000001');
    await tikla(tester, find.text('Cariyi kaydet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zaten kayıtlı'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '0000000100');
    await tikla(tester, find.text('Cariyi kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Örnek Yeni Cari'), findsOneWidget);
    expect(find.text('Henüz kart yok'), findsOneWidget);
  });
  testWidgets('Kilit tüm seçimi kapatır ve devamda kart seçilmemiştir', (
    tester,
  ) async {
    await baslat(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    await tikla(tester, find.byType(KartKutusu).first);
    await tester.pumpAndSettle();
    await tikla(tester, find.byTooltip('Ekranı kilitle'));
    await tester.pumpAndSettle();
    expect(find.text('Örnek Kuzey Market'), findsNothing);
    expect(find.text('Ekranın\nkilitlendi.'), findsOneWidget);
    await tikla(tester, find.text('Denemeye devam et'));
    await tester.pumpAndSettle();
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'POS’a geçişi dene'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Arka plana geçiş açık onay penceresini de kapatır', (
    tester,
  ) async {
    await baslat(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    await tikla(tester, find.byType(KartKutusu).first);
    await tester.pumpAndSettle();
    await tikla(tester, find.text('POS’a geçişi dene'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    // Gizliyken platform kare çizmez; geri dönüldüğünde kilit görünmelidir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Seçimini kontrol et'), findsNothing);
    expect(find.text('Denemeye devam et'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  for (final genislik in [320.0, 390.0, 1024.0]) {
    for (final olcek in [1.0, 1.5]) {
      testWidgets(
        '$genislik px / $olcek yazı ölçeğinde liste ve kartlar taşmaz',
        (tester) async {
          await baslat(tester, genislik: genislik, olcek: olcek);
          expect(tester.takeException(), isNull);
          await tikla(tester, find.text('Örnek Kuzey Market'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tikla(tester, find.byType(KartKutusu).first);
          await tester.pumpAndSettle();
          await tikla(tester, find.text('POS’a geçişi dene'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Canlı kip kurulmadığında deneme veya kayıt ekranına düşmez', (
    tester,
  ) async {
    await tester.pumpWidget(const BupPosApp(deneme: false));
    await tester.pumpAndSettle();
    expect(find.text('Kurulum\nbekleniyor.'), findsOneWidget);
    expect(find.text('Denemeyi aç'), findsNothing);
    expect(find.text('Örnek Kuzey Market'), findsNothing);
  });
  testWidgets('Boşta süresi dolunca ekran kilitlenir', (tester) async {
    await baslat(tester);
    await tester.pump(const Duration(minutes: 10, seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Denemeye devam et'), findsOneWidget);
  });
}
