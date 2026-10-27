// Android uygulama içi DenizPay uçtan uca (docs/ANDROID_PLANI.md Aşama 2).
// Yalnız emülatörde: yerel Firebase emülatörü + taklit DenizPay/banka
// (tools/android_taklit_denizpay.py, bilgisayarda 4199/4200). Gerçek DenizPay,
// banka, kart veya ödeme yoktur. tools/android_test.sh çalıştırır.
import 'dart:convert';
import 'dart:io';
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'yardimci.dart';

const _taklit = 'http://10.0.2.2:4199';

PlatformWebViewController _web(WidgetTester t) => t
    .widget<WebViewWidget>(find.byType(WebViewWidget))
    .platform
    .params
    .controller;

/// Taklit sayfada kişinin yapacağı şeyi (tıklama, form gönderme) yapar.
Future<Object> _js(WidgetTester t, String betik) async {
  final r = await _web(t).runJavaScriptReturningResult(betik);
  await t.pump(const Duration(milliseconds: 300));
  return r is String && r.startsWith('"') ? jsonDecode(r) as Object : r;
}

Future<String> _adres(WidgetTester t) async => await _web(t).currentUrl() ?? '';

Future<void> _cariEkle(WidgetTester t, String ad, String vkn) async {
  await bas(t, yeniCariDugmesi);
  await yaz(t, 'Cari adı', ad);
  await yaz(t, 'Vergi / TC kimlik numarası', vkn);
  await bas(t, find.text('Cariyi kaydet'));
}

Future<void> _denizPayaGir(WidgetTester t) async {
  await dokunVeBekle(
    t,
    find.text('Ödeme sitesine geç'),
    find.byType(CheckboxListTile),
  );
  await bas(t, find.byType(CheckboxListTile));
  // Android'de kontrol ve giriş tek dokunuş (0.12.0).
  expect(find.text('Seçimi kontrol et'), findsNothing);
  await bas(t, find.text('DenizPay’e giriş yap'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Uygulama içi DenizPay: kartlı ve kartsız giriş, kart doldurma, banka, sonuç kaydı',
    (t) async => bilinenEklentiKaydiyla(() => _akis(t)),
  );
}

Future<void> _akis(WidgetTester t) async {
  uygulama.main();
  await yaz(t, 'E-posta', 'satici-b@example.test');
  await yaz(t, 'Şifre', parola);
  await bas(t, find.text('Giriş yap'));

  // 1) Kartlı cari: "Kartı doldur" yalnız numara/ad/SKT yazar.
  await _cariEkle(t, 'Örnek Kartlı Cari', '0000000000');
  await bas(t, find.text('Kart ekle'));
  await yaz(t, 'Kart adı', 'Örnek İş Kartı');
  await yaz(t, 'Kart numarası', pan);
  await yaz(t, 'Kart üzerindeki ad (isteğe bağlı)', 'ÖRNEK KİŞİ');
  await yaz(t, 'Ay', '12');
  await yaz(t, 'Yıl', '2030');
  await bas(t, find.text('Kartı ve bu cari altında saklamayı kontrol ettim.'));
  await bas(t, find.text('Kartı kaydet'));
  final kart = find.bySemanticsLabel(RegExp('Örnek İş Kartı, son dört hane'));
  await bekle(t, kart);
  await t.pump(const Duration(seconds: 1));
  // Kişi gibi kartın üzerine (başlığına) dokunulur.
  await dokunVeBekle(
    t,
    find.text('Örnek İş Kartı'),
    find.byIcon(Icons.check_circle),
  );
  await _denizPayaGir(t);

  await bekle(t, find.text('Örnek Kartlı Cari'));
  await bas(t, find.text('Kartı doldur (•••• 1111)'));
  await bekle(t, find.textContaining('Kart yazıldı (•••• 1111)'));
  final kutular = await _js(
    t,
    'JSON.stringify(["number","name","expiry","cvc","Tutar"].map(function(i){return document.getElementById(i).value}))',
  );
  expect(jsonDecode(kutular as String), [
    '4111 1111 1111 1111',
    'ÖRNEK KİŞİ',
    '12 / 30',
    '',
    '',
  ]);

  // 2) İzin verilmeyen adresler açılmaz.
  final kartAdresi = await _adres(t);
  await _js(t, 'document.getElementById("kotu").click(); "ok"');
  await _js(t, 'document.getElementById("http").click(); "ok"');
  await t.pump(const Duration(seconds: 2));
  expect(await _adres(t), kartAdresi);

  // 3) Kişi ödemeyi gönderir → taklit 3D Secure (başka köken) → sonuç ekranı.
  await _js(t, 'document.getElementById("f").submit(); "ok"');
  await bekle(t, find.text('Banka sayfası: 10.0.2.2'));
  await bekle(t, find.text('Bu cariye kaydet: Örnek Kartlı Cari'));
  expect(find.textContaining('Ödeme başarılı · 4.500,00 TL'), findsOneWidget);
  await bas(t, find.text('Bu cariye kaydet: Örnek Kartlı Cari'));
  await bekle(t, find.textContaining('Kaydedildi: Örnek Kartlı Cari'));
  await bas(t, find.byTooltip('DenizPay’i kapat'));
  await bekle(t, find.text('Kart ekle'));

  // 4) Kartsız cari: kart seçmeden girilir, kart bilgileri elle yazılır.
  await bas(t, find.byTooltip('Carilere dön'));
  await bekle(t, yeniCariDugmesi);
  await _cariEkle(t, 'Örnek Kartsız Cari', '0000000001');
  await bekle(t, find.text('Ödeme sitesine geç'));
  await _denizPayaGir(t);
  await bekle(t, find.textContaining('Kart seçmedin'));
  expect(find.textContaining('Kartı doldur'), findsNothing);

  // 5) Başka firmanın kart sayfası: uyarı, kart yazılmaz.
  await _js(t, 'location.href = "$_taklit/baska-odeme.aspx"; "ok"');
  await bekle(t, find.textContaining('seçili cariye ait değil'));
  expect(find.textContaining('Kartı doldur'), findsNothing);
  await bas(t, find.byTooltip('DenizPay’i kapat'));
  await bas(t, find.widgetWithText(FilledButton, 'Kapat'));
  await bekle(t, find.text('Ödeme sitesine geç'));

  // 6) Gün sonunda uygulama içi kayıt; taklit sunucu iki girişi de doğru aldı.
  await bas(t, find.byTooltip('Carilere dön'));
  await bas(t, find.text('Gün sonu'));
  await bekle(t, find.textContaining('Örnek Kartlı Cari'));
  expect(find.textContaining('4.500,00'), findsWidgets);
  final istek = await HttpClient().getUrl(Uri.parse('$_taklit/girisler'));
  final girisler = await (await istek.close()).transform(utf8.decoder).join();
  expect(girisler.trim().split('\n'), ['0000000000 True', '0000000001 True']);
}
