import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';
import 'package:bup_sanal_pos/domain/kullanici.dart';
import 'package:bup_sanal_pos/ui/bilgi_sayfasi.dart';

// Bağlantıya tıklanmaz; yalnız hedefin aynı kökenli, verisiz deneme sayfası olduğu sınanır.
Future<void> ac(WidgetTester tester, Kullanici? kullanici) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BilgiSayfasi(kilitle: () {}, kullanici: kullanici),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hesaplı kullanıcıya verisiz telefon denemesi bağlantısı', (
    tester,
  ) async {
    await ac(
      tester,
      Kullanici(
        id: 'yapay',
        ad: 'Yapay Kullanıcı',
        eposta: 'yapay@example.invalid',
        yonetici: false,
        aktif: true,
      ),
    );
    final linkler = tester.widgetList<Link>(find.byType(Link)).toList();
    expect(linkler.map((l) => l.uri), [
      Uri.base.resolve('kurulum.html'),
      Uri.base.resolve('deneme.html'),
    ]);
    for (final link in linkler) {
      expect(link.uri!.hasQuery, isFalse);
      expect(link.uri!.hasFragment, isFalse);
    }
    expect(find.text('BUP Doldur yer imini kur'), findsOneWidget);
    expect(find.text('Telefon denemesini aç'), findsOneWidget);
    expect(find.text('BUP Sanal POS · 0.7.1'), findsOneWidget);
  });

  testWidgets('Deneme kipinde telefon denemesi gösterilmez', (tester) async {
    await ac(tester, null);
    expect(find.byType(Link), findsNothing);
  });
}
