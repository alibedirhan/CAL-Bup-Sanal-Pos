// Kamerayla kart okuma ekranı uçtan uca (0.12.0). Yalnız emülatörde (sanal arka
// kamera), yerel Firebase emülatörüyle: tools/android_test.sh. Kamera izni
// betikte adb ile verilir. Sanal sahnede kart yoktur: ekranın açıldığı,
// önizlemenin ve yazı tanımanın çalıştığı, kapanınca kameranın bırakıldığı
// (yeniden açılabildiği) sınanır. Gerçek kartla okuma Aşama 4'tedir.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:bup_sanal_pos/domain/kart_okuma.dart';
import 'package:bup_sanal_pos/main.dart' as uygulama;
import 'package:bup_sanal_pos/ui/kart_tarama_ekrani.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';
import 'yardimci.dart';

/// Yapay kart görüntüsü (test numarası); yalnız geçici klasörde, test sonunda silinir.
Future<File> yapayKart() async {
  final kayit = ui.PictureRecorder();
  final c = Canvas(kayit);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 1000, 630),
    Paint()..color = const Color(0xFF1D3557),
  );
  void yaz(String m, double x, double y, double boy) {
    final p = TextPainter(
      text: TextSpan(
        text: m,
        style: TextStyle(
          color: Colors.white,
          fontSize: boy,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, Offset(x, y));
  }

  yaz('ORNEK BANKA', 60, 50, 48);
  yaz('4111 1111 1111 1111', 60, 300, 72);
  yaz('VALID THRU  12/30', 60, 420, 40);
  yaz('ORNEK KISI', 60, 500, 44);
  final resim = await kayit.endRecording().toImage(1000, 630);
  final png = await resim.toByteData(format: ui.ImageByteFormat.png);
  final f = File('${Directory.systemTemp.path}/yapay_kart.png');
  await f.writeAsBytes(png!.buffer.asUint8List());
  return f;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cihaz içi yazı tanıma yapay kartı okur (ağsız ML Kit)', (
    t,
  ) async {
    final f = await t.runAsync(yapayKart);
    final tanima = TextRecognizer();
    try {
      final yazi = await t.runAsync(
        () => tanima.processImage(InputImage.fromFilePath(f!.path)),
      );
      final k = kartMetniniOku(yazi!.text, simdi: DateTime(2026, 10, 27));
      expect((k.numara, k.ay, k.yil), ('4111111111111111', 12, 2030));
    } finally {
      await tanima.close();
      await f?.delete();
    }
  });

  testWidgets(
    'Android: kamerayla okuma ekranı açılır, kapanınca kamera bırakılır',
    (t) async {
      await bilinenEklentiKaydiyla(() async {
        uygulama.main();
        await yaz(t, 'E-posta', 'satici-a@example.test');
        await yaz(t, 'Şifre', parola);
        await bas(t, find.text('Giriş yap'));
        await bas(t, yeniCariDugmesi);
        await yaz(t, 'Cari adı', 'Örnek Kamera Carisi');
        await yaz(t, 'Vergi / TC kimlik numarası', '0000000017');
        await bas(t, find.text('Cariyi kaydet'));
        await bas(t, find.text('Kart ekle'));

        // Emülatörde NFC yok: yalnız kamera düğmesi.
        await bekle(t, find.text('Kamerayla oku'));
        expect(find.text('Temassız oku'), findsNothing);

        for (var tur = 0; tur < 2; tur++) {
          await bas(t, find.text('Kamerayla oku'));
          await bekle(t, find.byType(KartTaramaEkrani));
          await bekle(t, find.textContaining('çerçeveye al'), saniye: 20);
          expect(find.byType(CameraPreview), findsOneWidget);
          // Yazı tanıma birkaç kare işlesin (çökme/hata olmamalı).
          await t.pump(const Duration(seconds: 3));
          expect(find.byType(KartTaramaEkrani), findsOneWidget);
          await bas(t, find.text('Vazgeç'));
          // Ekran kapanır ve kamera bırakılır (ikinci turda yeniden açılabilmeli).
          for (
            var i = 0;
            i < 100 && find.byType(KartTaramaEkrani).evaluate().isNotEmpty;
            i++
          ) {
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(find.byType(KartTaramaEkrani), findsNothing);
          expect(find.text('Kartı kaydet'), findsOneWidget);
        }
      });
    },
  );
}
