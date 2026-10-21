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
    final link = tester.widget<Link>(find.byType(Link));
    expect(link.uri, Uri.base.resolve('deneme.html'));
    expect(link.uri!.hasQuery, isFalse);
    expect(link.uri!.hasFragment, isFalse);
    expect(find.text('Telefon denemesini aç'), findsOneWidget);
    expect(find.text('BUP Sanal POS · 0.6.0'), findsOneWidget);
  });

  testWidgets('Deneme kipinde telefon denemesi gösterilmez', (tester) async {
    await ac(tester, null);
    expect(find.byType(Link), findsNothing);
  });
}
