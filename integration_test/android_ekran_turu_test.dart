// Arayüz gözden geçirme aracı (test takımında DEĞİL): ana ekranları sırayla
// açar ve her birinde "EKRAN:<ad>" yazar; tools/ekran_turu.sh o an emülatörün
// ekran görüntüsünü alır. Yalnız emülatör ve yapay veri.
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'yardimci.dart';

Future<void> ekran(WidgetTester t, String ad) async {
  await t.pump(const Duration(milliseconds: 800));
  // ignore: avoid_print
  print('EKRAN:$ad');
  await t.pump(const Duration(milliseconds: 2500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ekran turu', (t) async {
    await bilinenEklentiKaydiyla(() async {
      uygulama.main();
      await bekle(t, find.text('Giriş yap'));
      await ekran(t, '01_giris');
      await yaz(t, 'E-posta', 'satici-a@example.test');
      await yaz(t, 'Şifre', parola);
      await bas(t, find.text('Giriş yap'));
      await bekle(t, yeniCariDugmesi);
      await ekran(t, '02_cariler_bos');

      await bas(t, yeniCariDugmesi);
      await bekle(t, find.text('Cariyi kaydet'));
      await ekran(t, '03_yeni_cari');
      await yaz(t, 'Cari adı', 'Örnek Market Gıda Ltd. Şti.');
      await ekran(t, '04_yeni_cari_klavye');
      await yaz(t, 'Vergi / TC kimlik numarası', '0000000025');
      await bas(t, find.text('Cariyi kaydet'));
      await bekle(t, find.text('Kart ekle'));
      await ekran(t, '05_cari_profili');

      await bas(t, find.text('Kart ekle'));
      await bekle(t, find.text('Kartı kaydet'));
      await ekran(t, '06_kart_formu');
      await yaz(t, 'Kart adı', 'İş kartı');
      await yaz(t, 'Kart numarası', pan);
      await yaz(t, 'Ay', '12');
      await yaz(t, 'Yıl', '2030');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump(const Duration(milliseconds: 500));
      await t.ensureVisible(find.text('Kartı kaydet'));
      await ekran(t, '07_kart_formu_alt');
      await bas(
        t,
        find.text('Kartı ve bu cari altında saklamayı kontrol ettim.'),
      );
      await bas(t, find.text('Kartı kaydet'));
      await bekle(t, find.text('Yeni PIN belirle'));
      await ekran(t, '08_pin_belirle');
      for (final r in '482915'.split('')) {
        await t.tap(find.byKey(ValueKey('pin-$r')));
        await t.pump(const Duration(milliseconds: 80));
      }
      await bekle(t, find.text('Aynı PIN’i tekrar yaz'));
      await ekran(t, '09_pin_tekrar');
      for (final r in '482915'.split('')) {
        await t.tap(find.byKey(ValueKey('pin-$r')));
        await t.pump(const Duration(milliseconds: 80));
      }
      await bekle(t, find.bySemanticsLabel(RegExp('son dört hane 1111')));
      await ekran(t, '10_cari_profili_kartli');

      await dokunVeBekle(
        t,
        find.text('Ödeme sitesine geç'),
        find.byType(CheckboxListTile),
      );
      await ekran(t, '11_odeme_onayi');
      t.state<NavigatorState>(find.byType(Navigator).last).pop();
      await t.pump(const Duration(seconds: 1));

      await bas(t, find.byTooltip('Carilere dön'));
      await bekle(t, yeniCariDugmesi);
      await ekran(t, '12_cariler_dolu');
      await bas(t, find.text('Gün sonu'));
      await ekran(t, '13_gun_sonu');
      await bas(t, find.text('Çalışma alanı'));
      await ekran(t, '14_calisma_alani');
      await bas(t, find.byTooltip('Ekranı kilitle'));
      await bekle(t, find.text('Kilidi aç'));
      await ekran(t, '15_kilit');
    });
  });
}
