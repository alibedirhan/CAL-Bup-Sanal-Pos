// Android sürüm denetimi uçtan uca (docs/ANDROID_PLANI.md Aşama 3). Yalnız
// emülatörde, yerel Firebase emülatörüyle (demo-bup-pos): tools/android_test.sh.
import 'dart:convert';
import 'dart:io';
import 'package:bup_sanal_pos/data/android/kanal.dart';
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:bup_sanal_pos/ui/guncelleme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher/link.dart';
import 'yardimci.dart';

/// `ayarlar/android` istemciden yazılamaz (kural); test, emülatörün yönetici
/// yetkisiyle ("Bearer owner") yazar — yalnız Firebase emülatöründe geçerlidir.
Future<void> ayarYaz(int enDusuk, int son) async {
  const host = String.fromEnvironment('BUP_EMULATOR_HOST');
  final istemci = HttpClient();
  try {
    final istek = await istemci.patchUrl(
      Uri.parse(
        'http://$host:8088/v1/projects/demo-bup-pos/databases/(default)/documents/ayarlar/android',
      ),
    );
    istek.headers
      ..set('Authorization', 'Bearer owner')
      ..contentType = ContentType.json;
    istek.write(
      jsonEncode({
        'fields': {
          'enDusuk': {'integerValue': '$enDusuk'},
          'son': {'integerValue': '$son'},
          'sonAd': {'stringValue': '9.9.9'},
          'indirme': {'stringValue': 'https://indir.example.test/'},
          'sha256': {'stringValue': 'ab' * 32},
        },
      }),
    );
    final yanit = await istek.close();
    expect(yanit.statusCode, 200);
    await yanit.drain<void>();
  } finally {
    istemci.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: en düşük sürümün altında yalnız güncelleme ekranı', (
    t,
  ) async {
    // Kurulu APK'nın versionCode'u pubspec'teki derleme numarasıdır.
    final kod = await guvenlikKanali.invokeMethod<int>('surum');
    expect(kod, greaterThanOrEqualTo(19));
    await ayarYaz(kod! + 1, kod + 1);

    uygulama.main();
    await yaz(t, 'E-posta', 'satici-a@example.test');
    await yaz(t, 'Şifre', parola);
    await bas(t, find.text('Giriş yap'));
    await bekle(t, find.text('Güncelleme gerekli'));
    expect(find.text('Yeni cari'), findsNothing);
    final link = t.widget<Link>(find.byType(Link));
    expect(link.uri, Uri.parse('https://indir.example.test/'));
    expect(find.text('9.9.9 sürümünü indir'), findsOneWidget);
    await bas(t, find.text('Çıkış yap'));
    await bekle(t, find.text('Giriş yap'));

    // Yayındaki sürüm daha yeni ama bu sürüm hâlâ izinli: uygulama açılır, not.
    await ayarYaz(kod, kod + 1);
    await yaz(t, 'E-posta', 'satici-a@example.test');
    await yaz(t, 'Şifre', parola);
    await bas(t, find.text('Giriş yap'));
    await bekle(t, find.text('Yeni sürüm hazır: 9.9.9'));
    expect(find.text('Yeni cari'), findsOneWidget);
    await bas(t, find.byTooltip('Notu kapat'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(GuncellemeNotu), findsNothing);

    // Güncel: not yok.
    await ayarYaz(kod, kod);
    await bas(t, find.byTooltip('Ekranı kilitle'));
    await yaz(t, 'Şifre', parola);
    await bas(t, find.text('Kilidi aç'));
    await bekle(t, find.text('Yeni cari'));
    await t.pump(const Duration(seconds: 2));
    expect(find.byType(GuncellemeNotu), findsNothing);
  });
}
