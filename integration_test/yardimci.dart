// Android uçtan uca testlerinin ortak yardımcıları (yalnız emülatör, yapay veri).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const parola = 'YapayDenemeSifresi-2026!';
const pan = '4111111111111111';

/// Başarısızlıkta ekrandaki bütün yazılar rapora girer (yapay veri).
String yazilar() => [
  for (final e in find.byType(Text).evaluate()) ?(e.widget as Text).data,
].join(' | ');

Future<void> bekle(WidgetTester t, Finder f, {int saniye = 30}) async {
  for (var i = 0; i < saniye * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Ekranda bulunamadı: $f\nEkrandaki yazılar: ${yazilar()}');
}

Future<void> yaz(WidgetTester t, String etiket, String deger) async {
  final f = find.widgetWithText(TextFormField, etiket);
  await bekle(t, f);
  await t.ensureVisible(f);
  // Kişinin yaptığı gibi önce alana dokunulur: aynı alana ikinci kez yazarken
  // test aracı eski klavye bağlantısını kullanmasın.
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 200));
  await t.enterText(f, deger);
  await t.pump();
  expect(
    t.widget<TextFormField>(f).controller?.text ?? deger,
    deger,
    reason: '$etiket alanına yazılamadı',
  );
}

Future<void> bas(WidgetTester t, Finder f) async {
  await bekle(t, f);
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f.first);
  await t.pump();
}

/// Dokunur ve [sonuc] görünene kadar bekler. Uygulama kısa süre meşgulken
/// (ör. kart kaydı sonrası) düğmeler kapalıdır: dokunuş boşa giderse yinelenir.
Future<void> dokunVeBekle(WidgetTester t, Finder hedef, Finder sonuc) async {
  for (var deneme = 0; deneme < 5; deneme++) {
    await bas(t, hedef);
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (sonuc.evaluate().isNotEmpty) return;
    }
  }
  throw TestFailure('Dokunuş sonuç vermedi: $hedef → $sonuc\n${yazilar()}');
}

/// cloud_firestore Android eklentisinin bilinen kaydı: işlem (transaction)
/// bittikten sonra eklenti kanalı kaldırıyor, Dart tarafı "cancel" çağırınca
/// MissingPluginException raporlanıyor. Kayıt başarılıdır, uygulama
/// etkilenmez. Yalnız bu tam ileti sayılır; başka her hata testi düşürür.
Future<void> bilinenEklentiKaydiyla(Future<void> Function() akis) async {
  final onceki = FlutterError.onError;
  var eklentiKaydi = 0;
  FlutterError.onError = (d) {
    final m = d.exceptionAsString();
    if (d.exception is MissingPluginException &&
        m.contains('method cancel on channel') &&
        m.contains('plugins.flutter.io/firebase_firestore/transaction/')) {
      eklentiKaydi++;
      return;
    }
    onceki?.call(d);
  };
  try {
    await akis();
  } finally {
    FlutterError.onError = onceki;
  }
  // ignore: avoid_print
  print('Bilinen Firestore eklenti kaydı: $eklentiKaydi');
}
