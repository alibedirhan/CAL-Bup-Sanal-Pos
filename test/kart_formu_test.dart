import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/ui/cari_profili.dart';
import 'package:bup_sanal_pos/ui/kart_formu.dart';
import 'arayuz_test.dart' show baslat, tikla;

EditableText alan(WidgetTester tester, String etiket) => tester.widget(
  find.descendant(
    of: find.widgetWithText(TextField, etiket),
    matching: find.byType(EditableText),
  ),
);

void main() {
  // Telefonun kart tarama/önerme özelliği yalnız kart türü bildirilen, gizli
  // olmayan kutuda çıkar. Görüntü veya öneri uygulamaya ayrıca gönderilmez.
  testWidgets('Yeni kart formu alanları tarayıcıya kart alanı bildirir', (
    tester,
  ) async {
    await baslat(tester);
    await tikla(tester, find.text('Örnek Kuzey Market'));
    await tester.pumpAndSettle();
    final ekran = find.byType(CariProfiliEkrani);
    kartFormunuAc(
      tester.element(ekran),
      tester.widget<CariProfiliEkrani>(ekran).model,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AutofillGroup), findsOneWidget);
    final numara = alan(tester, 'Kart numarası');
    expect(numara.autofillHints, [AutofillHints.creditCardNumber]);
    expect(numara.obscureText, isFalse);
    expect(alan(tester, 'Kart üzerindeki ad (isteğe bağlı)').autofillHints, [
      AutofillHints.creditCardName,
    ]);
    expect(alan(tester, 'Ay').autofillHints, [
      AutofillHints.creditCardExpirationMonth,
    ]);
    expect(alan(tester, 'Yıl').autofillHints, [
      AutofillHints.creditCardExpirationYear,
    ]);
    // CVV kutusu yoktur; tarama CVV okusa bile yazacak alan bulunmaz.
    expect(find.textContaining('CVV'), findsWidgets);
    expect(find.widgetWithText(TextField, 'CVV'), findsNothing);
    // "Karttan oku" kutusu tarayıcının kart doldurmasına katılmaz.
    expect(alan(tester, 'Karttan oku (isteğe bağlı)').autofillHints, isNull);
  });

  testWidgets('Karttan okunan yazı doğru kutulara dağılır, kutu temizlenir', (
    tester,
  ) async {
    await formuAc(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Karttan oku (isteğe bağlı)'),
      'ÖRNEK BANKASI\n4111 1111 1111 1111\nVALID THRU 07/31\nAHMET YILMAZ\nCVV 123',
    );
    await tester.pumpAndSettle();
    expect(deger(tester, 'Kart numarası'), '4111111111111111');
    expect(deger(tester, 'Ay'), '07');
    expect(deger(tester, 'Yıl'), '2031');
    expect(deger(tester, 'Kart üzerindeki ad (isteğe bağlı)'), 'AHMET YILMAZ');
    expect(deger(tester, 'Karttan oku (isteğe bağlı)'), '');
    expect(alan(tester, 'Kart numarası').obscureText, isFalse);
    expect(find.textContaining('Yazıldı: •••• 1111 · 07 / 2031'), findsOne);
    expect(find.textContaining('123'), findsNothing);
  });

  testWidgets('Okunamayan yazı hiçbir kutuyu değiştirmez', (tester) async {
    await formuAc(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Karttan oku (isteğe bağlı)'),
      'bu bir kart yazısı değil',
    );
    await tester.pumpAndSettle();
    expect(deger(tester, 'Kart numarası'), '');
    expect(deger(tester, 'Ay'), '');
    expect(find.textContaining('okunamadı'), findsOne);
  });

  testWidgets(
    'Tek parça tarih ay ve yıl kutularına bölünür, iki haneli yıl geçer',
    (tester) async {
      await formuAc(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ay'), '07/31');
      await tester.pumpAndSettle();
      expect(deger(tester, 'Ay'), '07');
      expect(deger(tester, 'Yıl'), '2031');
      await tester.enterText(find.widgetWithText(TextField, 'Yıl'), '31');
      await tester.pumpAndSettle();
      final form = tester.state<FormState>(find.byType(Form));
      form.validate();
      await tester.pumpAndSettle();
      expect(find.text('2031 ya da 31 yaz.'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Yıl'), '20');
      form.validate();
      await tester.pumpAndSettle();
      expect(find.text('Kartın süresi geçmiş.'), findsOne);
    },
  );
}

Future<void> formuAc(WidgetTester tester) async {
  await baslat(tester);
  await tikla(tester, find.text('Örnek Kuzey Market'));
  await tester.pumpAndSettle();
  final ekran = find.byType(CariProfiliEkrani);
  kartFormunuAc(
    tester.element(ekran),
    tester.widget<CariProfiliEkrani>(ekran).model,
  );
  await tester.pumpAndSettle();
}

String deger(WidgetTester tester, String etiket) =>
    alan(tester, etiket).controller.text;
