// Gizli konum kurulumu uçtan uca (docs/ROTA_MIMARI.md M16). Yalnız emülatörde, yerel Firebase
// emülatörüyle (demo-bup-pos), yapay yönetici hesabı. 17 Kasım 2026: gerçek telefonda şifre
// doğrulandıktan sonra kurulum sayfası kayboluyordu (profil dinleyicisinin geçici hatası;
// emülatörde kendiliğinden oluşmuyor, kural `profilHatasiOturumuKapatir` birim testli).
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'yardimci.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Yönetici kurulumu şifreden sonra açılır ve açık kalır', (
    t,
  ) async {
    await bilinenEklentiKaydiyla(() => akis(t));
  });
}

Future<void> akis(WidgetTester t) async {
  uygulama.main();
  await yaz(t, 'E-posta', 'admin@example.test');
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Giriş yap'));
  await bekle(t, yeniCariDugmesi);

  await bas(t, find.text('Çalışma alanı'));
  await bas(t, find.text('Yönetici kurulumu'));
  final sifre = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  await bekle(t, sifre);

  await t.enterText(sifre, parola);
  await bas(t, find.text('Devam'));
  await bekle(t, find.text('Terminal kodu'));
  // Kurulum sayfası birkaç saniye sonra da açık olmalı: şifre doğrulanınca profil
  // dinleyicisinin geçici bağlantı hatası ekranı sıfırlamamalı (17 Kasım 2026).
  for (var i = 0; i < 50; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Terminal kodu'), findsOneWidget, reason: yazilar());
  expect(find.text('Konum izni'), findsOneWidget);
}
