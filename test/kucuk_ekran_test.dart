import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/app.dart';
import 'package:bup_sanal_pos/ui/kart_kutusu.dart';
import 'arayuz_test.dart' show tikla;

// iPhone SE 2020: Safari çubuklarıyla görünen alan yaklaşık 375 × 548.
const _se = Size(375, 548);

Future<void> baslatSe(WidgetTester tester) async {
  tester.view.physicalSize = _se;
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

void main() {
  testWidgets('Küçük ekranda cariler kaydırmadan görünür', (tester) async {
    await baslatSe(tester);
    final alt = _se.height - 80; // alt sekme çubuğunun üstü
    expect(
      tester.getBottomLeft(find.text('Örnek Kuzey Market')).dy,
      lessThan(alt),
    );
  });

  testWidgets('Alttan açılan pencere üstte boşluk bırakır', (tester) async {
    await baslatSe(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    await tikla(tester, find.text('Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Cariyi düzenle'), findsOneWidget);
    // Tutma çizgisi ekranın tepesine yapışmaz; parmakla aşağı çekilebilir.
    expect(
      tester.getTopLeft(find.byType(BottomSheet)).dy,
      greaterThanOrEqualTo(_se.height * 0.1),
    );
  });

  testWidgets('Profilde kartlar cari işlemlerinden önce gelir', (tester) async {
    await baslatSe(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    final kart = tester.getTopLeft(find.byType(KartKutusu).first).dy;
    expect(kart, lessThan(_se.height - 120)); // alt işlem çubuğunun üstünde
    expect(kart, lessThan(tester.getTopLeft(find.text('Cari bilgileri')).dy));
  });

  testWidgets('Form uyarısı düzeltilince kendiliğinden kalkar', (tester) async {
    await baslatSe(tester);
    await tikla(tester, find.text('Yeni cari'));
    await tester.pumpAndSettle();
    await tikla(tester, find.text('Cariyi kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('En az 2 karakterlik bir ad yazın.'), findsOneWidget);
    expect(find.text('10 veya 11 rakam yaz.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cari adı'),
      'Örnek Yeni Market',
    );
    await tester.pumpAndSettle();
    expect(find.text('En az 2 karakterlik bir ad yazın.'), findsNothing);
    // Düzeltilmeyen alanın uyarısı durur.
    expect(find.text('10 veya 11 rakam yaz.'), findsOneWidget);
  });
}
