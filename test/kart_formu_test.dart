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
    expect(find.textContaining('CVV'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'CVV'), findsNothing);
  });
}
