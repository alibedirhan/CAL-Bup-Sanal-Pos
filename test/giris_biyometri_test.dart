import 'package:bup_sanal_pos/application/hesap_portu.dart';
import 'package:bup_sanal_pos/ui/giris_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SahteHesap implements HesapPortu {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  Future<void> ac(
    WidgetTester t, {
    Future<String?> Function()? biyometri,
    required List<String> sifreler,
  }) => t.pumpWidget(
    MaterialApp(
      home: GirisSayfasi(
        hesap: SahteHesap(),
        eposta: 'a@b.c',
        kilitli: true,
        giris: (p) async => sifreler.add(p),
        biyometri: biyometri,
      ),
    ),
  );

  testWidgets(
    'Biyometri kendiliğinden bir kez sorulur; vazgeçince düğme kalır',
    (t) async {
      var soru = 0;
      await ac(
        t,
        sifreler: [],
        biyometri: () async {
          soru++;
          return null;
        },
      );
      await t.pumpAndSettle();
      expect(soru, 1);
      await t.pump();
      await t.pumpAndSettle();
      expect(soru, 1, reason: 'yeniden çizimde tekrar sorulmaz');
      await t.tap(find.text('Parmak iziyle aç'));
      await t.pumpAndSettle();
      expect(soru, 2);
    },
  );

  testWidgets('Biyometri mesajı gösterilir; şifreyle açma her zaman var', (
    t,
  ) async {
    final sifreler = <String>[];
    await ac(
      t,
      sifreler: sifreler,
      biyometri: () async => 'Hesap şifreni yaz.',
    );
    await t.pumpAndSettle();
    expect(find.text('Hesap şifreni yaz.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'gizli1');
    await t.tap(find.text('Kilidi aç'));
    await t.pumpAndSettle();
    expect(sifreler, ['gizli1']);
  });

  testWidgets('Biyometri yoksa düğme yok ve sorulmaz', (t) async {
    await ac(t, sifreler: []);
    await t.pumpAndSettle();
    expect(find.text('Parmak iziyle aç'), findsNothing);
  });
}
