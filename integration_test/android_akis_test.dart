// Android uçtan uca (docs/ANDROID_PLANI.md Aşama 1). Yalnız emülatörde, yerel
// Firebase emülatörüyle (demo-bup-pos) ve yapay verilerle çalışır:
// tools/android_test.sh. Gerçek Firebase, POS veya kart kullanılmaz.
import 'dart:io';
import 'package:bup_sanal_pos/data/android/kanal.dart';
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:bup_sanal_pos/ui/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'yardimci.dart';

/// Kart formunu açar, numaranın Keystore'dan çözülmesini bekler, karşılaştırır.
Future<void> kartiAcVeDenetle(WidgetTester t) async {
  await bas(t, find.text('Bilgiler / düzenle'));
  final alan = find.widgetWithText(TextFormField, 'Kart numarası');
  await bekle(t, alan);
  String numara() =>
      t.widget<TextFormField>(alan).controller!.text.replaceAll(' ', '');
  for (var i = 0; i < 150 && numara().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (numara().isEmpty) {
    fail('Kart numarası çözülmedi. Ekrandaki yazılar: ${yazilar()}');
  }
  await bas(t, find.byTooltip('Kart numarasını göster'));
  expect(numara(), pan);
  t.state<NavigatorState>(find.byType(Navigator).last).pop();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android: giriş, cari, Keystore kart kasası, kilit ve şifreyle açma',
    (t) async {
      await bilinenEklentiKaydiyla(() => akis(t));
    },
  );
}

Future<void> akis(WidgetTester t) async {
  uygulama.main();
  await yaz(t, 'E-posta', 'satici-a@example.test');
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Giriş yap'));

  await bas(t, yeniCariDugmesi);
  await yaz(t, 'Cari adı', 'Örnek Android Carisi');
  await yaz(t, 'Vergi / TC kimlik numarası', '0000000000');
  await bas(t, find.text('Cariyi kaydet'));

  await bas(t, find.text('Kart ekle'));
  await yaz(t, 'Kart adı', 'Örnek İş Kartı');
  await yaz(t, 'Kart numarası', pan);
  await yaz(t, 'Kart üzerindeki ad (isteğe bağlı)', 'ÖRNEK KİŞİ');
  await yaz(t, 'Ay', '12');
  await yaz(t, 'Yıl', '2030');
  await bas(t, find.text('Kartı ve bu cari altında saklamayı kontrol ettim.'));
  await bas(t, find.text('Kartı kaydet'));
  final kart = find.bySemanticsLabel(
    RegExp('Örnek İş Kartı, son dört hane 1111'),
  );
  await bekle(t, kart);
  await t.pump(const Duration(seconds: 1));

  // Kasa belgesi uygulamanın yedeğe girmeyen klasöründe; düz kart içermez.
  final kasa = Directory('${await yedeksizKlasor()}/kart-kasasi');
  final belgeler = kasa.listSync().whereType<File>().toList();
  expect(belgeler, hasLength(1));
  final icerik = await belgeler.single.readAsString();
  for (final gizli in [pan, 'ÖRNEK KİŞİ', '1111111111']) {
    expect(icerik.contains(gizli), isFalse, reason: gizli);
  }

  await kartiAcVeDenetle(t);

  // Elle kilit → yanlış şifre reddedilir → doğru şifreyle açılır → kart
  // Keystore'dan yeniden çözülür.
  await bas(t, find.byTooltip('Ekranı kilitle'));
  await bekle(t, find.text('Kilidi aç'));
  expect(find.text('Parmak iziyle aç'), findsNothing);
  await yaz(t, 'Şifre', 'yanlis-sifre');
  await bas(t, find.text('Kilidi aç'));
  await bekle(t, find.byType(DurumNotu));
  expect(find.text('Kilidi aç'), findsOneWidget);
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Kilidi aç'));
  await bekle(t, yeniCariDugmesi);
  await bas(t, find.textContaining('Örnek Android Carisi'));
  await bekle(t, kart);
  await kartiAcVeDenetle(t);
}
