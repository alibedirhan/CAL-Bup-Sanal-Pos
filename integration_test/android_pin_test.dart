// Ekran kilidi olmayan telefonda uygulama PIN'i uçtan uca (kullanıcı kararı,
// 27 Ekim 2026). Yalnız emülatörde, ekran kilidi KALDIRILMIŞKEN, yerel Firebase
// emülatörüyle (demo-bup-pos): tools/android_test.sh. Yapay veri.
import 'dart:io';
import 'package:bup_sanal_pos/data/android/kanal.dart';
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'yardimci.dart';

const pin = '482915';

Future<void> pinYaz(WidgetTester t, String etiket, String deger) async {
  final f = find.widgetWithText(TextField, etiket);
  await bekle(t, f);
  await t.enterText(f, deger);
  await t.pump();
}

/// Kart formunu açar; [pinSor] ise önce PIN penceresi beklenir.
Future<void> kartiAc(WidgetTester t, {String? pinSor, String? yanlis}) async {
  await bas(t, find.text('Bilgiler / düzenle'));
  if (pinSor != null) {
    if (yanlis != null) {
      await pinYaz(t, 'PIN', yanlis);
      await bas(t, find.text('Aç'));
      await bekle(t, find.textContaining('PIN yanlış.'));
    }
    await pinYaz(t, 'PIN', pinSor);
    await bas(t, find.text('Aç'));
  }
  final alan = find.widgetWithText(TextFormField, 'Kart numarası');
  await bekle(t, alan);
  String numara() =>
      t.widget<TextFormField>(alan).controller!.text.replaceAll(' ', '');
  for (var i = 0; i < 150 && numara().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (numara().isEmpty) fail('Kart numarası çözülmedi: ${yazilar()}');
  await bas(t, find.byTooltip('Kart numarasını göster'));
  expect(numara(), pan);
  t.state<NavigatorState>(find.byType(Navigator).last).pop();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android, ekran kilidi yok: kart uygulama PIN’iyle korunur', (
    t,
  ) async {
    await bilinenEklentiKaydiyla(() => akis(t));
  });
}

Future<void> akis(WidgetTester t) async {
  uygulama.main();
  await yaz(t, 'E-posta', 'satici-a@example.test');
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Giriş yap'));

  await bas(t, find.text('Yeni cari'));
  await yaz(t, 'Cari adı', 'Örnek PIN Carisi');
  // Diğer uçtan uca testlerin carilerinden ayrı VKN (aynı emülatör verisi).
  await yaz(t, 'Vergi / TC kimlik numarası', '0000000009');
  await bas(t, find.text('Cariyi kaydet'));

  await bas(t, find.text('Kart ekle'));
  await yaz(t, 'Kart adı', 'Örnek PIN Kartı');
  await yaz(t, 'Kart numarası', pan);
  await yaz(t, 'Ay', '12');
  await yaz(t, 'Yıl', '2030');
  await bas(t, find.text('Kartı ve bu cari altında saklamayı kontrol ettim.'));
  await bas(t, find.text('Kartı kaydet'));

  // İlk kart: PIN belirlenir; tahmini kolay PIN reddedilir.
  await bekle(t, find.text('Uygulama PIN’i belirle'));
  await pinYaz(t, 'PIN', '123456');
  await pinYaz(t, 'PIN (tekrar)', '123456');
  await bas(t, find.text('PIN’i kaydet'));
  await bekle(t, find.textContaining('kolay'));
  await pinYaz(t, 'PIN', pin);
  await pinYaz(t, 'PIN (tekrar)', pin);
  await bas(t, find.text('PIN’i kaydet'));
  final kart = find.bySemanticsLabel(
    RegExp('Örnek PIN Kartı, son dört hane 1111'),
  );
  await bekle(t, kart);
  await t.pump(const Duration(seconds: 1));

  // Aynı oturumda PIN yeniden sorulmaz.
  await kartiAc(t);

  // Dosyalarda PIN ve kart numarası düz yazılmaz.
  final kok = await yedeksizKlasor();
  for (final klasor in ['kart-kasasi', 'kart-pin']) {
    final belgeler = Directory('$kok/$klasor').listSync().whereType<File>();
    expect(belgeler, isNotEmpty, reason: klasor);
    for (final b in belgeler) {
      final icerik = await b.readAsString();
      for (final gizli in [pan, pin, '1111111111']) {
        expect(icerik.contains(gizli), isFalse, reason: '$klasor: $gizli');
      }
    }
  }

  // Kilit → hesap şifresi → kart açılırken PIN; yanlış PIN reddedilir.
  await bas(t, find.byTooltip('Ekranı kilitle'));
  await bekle(t, find.text('Kilidi aç'));
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Kilidi aç'));
  await bekle(t, find.text('Yeni cari'));
  await bas(t, find.textContaining('Örnek PIN Carisi'));
  await bekle(t, kart);
  await kartiAc(t, pinSor: pin, yanlis: '000000');
}
