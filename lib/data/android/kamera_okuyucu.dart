import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../application/kart_tarama.dart';
import '../../domain/kart_okuma.dart';
import 'kanal.dart';

/// Kamerayla kart okuma: önizleme karelerinde cihaz içi yazı tanıma (Google ML
/// Kit, Latin; ağ kullanmaz). Kareler yalnız bellekte işlenir: fotoğraf
/// çekilmez, dosyaya yazılmaz, gönderilmez. Yazı `kartMetniniOku` ile
/// ayrıştırılır; numara (Luhn) iki ayrı karede aynı okununca kabul edilir.
class KameraOkuyucu implements KartTaramaOturumu {
  KameraOkuyucu({required this.saat});
  final DateTime Function() saat;
  final _olaylar = StreamController<TaramaOlayi>.broadcast();
  final _kamera = ValueNotifier<CameraController?>(null);
  final _tanima = TextRecognizer();
  bool _kapali = false, _isleniyor = false, _bitti = false;
  DateTime _son = DateTime(0);
  final _birlestirici = KareBirlestirici();

  /// Kare işleme aralığı.
  static const _aralik = Duration(milliseconds: 350);

  /// Önizleme (ekran bu görünümü gösterir).
  Widget get gorunum => ValueListenableBuilder(
    valueListenable: _kamera,
    builder: (_, k, _) => k == null || !k.value.isInitialized
        ? const SizedBox.shrink()
        : CameraPreview(k),
  );

  @override
  Stream<TaramaOlayi> get olaylar => _olaylar.stream;

  void _bildir(TaramaOlayi o) {
    if (!_kapali) _olaylar.add(o);
  }

  @override
  Future<void> baslat() async {
    final kameralar = await availableCameras();
    final arka = kameralar
        .where((k) => k.lensDirection == CameraLensDirection.back)
        .firstOrNull;
    if (arka == null) {
      return _bildir(
        const TaramaNotu('Bu cihazda arka kamera yok.', hata: true),
      );
    }
    final k = CameraController(
      arka,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    try {
      await k.initialize();
    } on CameraException catch (e) {
      await k.dispose();
      return _bildir(
        e.code.contains('Denied') || e.code.contains('denied')
            ? const TaramaNotu(
                'Kamera izni verilmedi. Ayarlardan bu uygulamaya kamera izni ver.',
                hata: true,
                ayarlar: true,
              )
            : const TaramaNotu('Kamera açılamadı.', hata: true),
      );
    }
    if (_kapali) return k.dispose();
    _kamera.value = k;
    await k.setFlashMode(FlashMode.off);
    await k.startImageStream((kare) => _kare(kare, arka.sensorOrientation));
    _bildir(
      const TaramaNotu(
        'Kartın ön yüzünü çerçeveye al; numara okunana kadar sabit tut.',
      ),
    );
  }

  Future<void> _kare(CameraImage kare, int yon) async {
    final simdi = DateTime.now();
    if (_isleniyor || _bitti || simdi.difference(_son) < _aralik) return;
    _isleniyor = true;
    _son = simdi;
    try {
      final girdi = InputImage.fromBytes(
        bytes: kare.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(kare.width.toDouble(), kare.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(yon) ??
              InputImageRotation.rotation90deg,
          format: InputImageFormat.nv21,
          bytesPerRow: kare.planes.first.bytesPerRow,
        ),
      );
      final yazi = await _tanima.processImage(girdi);
      if (!_bitti) _degerlendir(kartMetniniOku(yazi.text, simdi: saat()));
    } catch (_) {
      // Tek karenin hatası okumayı durdurmaz.
    } finally {
      _isleniyor = false;
    }
  }

  void _degerlendir(OkunanKart k) {
    final kart = _birlestirici.ekle(k);
    if (kart == null) {
      if (_birlestirici.tarihAraniyor) {
        _bildir(
          const TaramaNotu('Numara okundu; son kullanma tarihi aranıyor…'),
        );
      }
      return;
    }
    _bitti = true;
    unawaited(_kamera.value?.stopImageStream().catchError((Object _) {}));
    _bildir(TaramaOkundu(kart));
  }

  @override
  Future<void> ayarlariAc() =>
      guvenlikKanali.invokeMethod<void>('ayarlar.uygulama');

  @override
  Future<void> kapat() async {
    if (_kapali) return;
    _kapali = true;
    _bitti = true;
    final k = _kamera.value;
    _kamera.value = null;
    try {
      if (k?.value.isStreamingImages == true) await k!.stopImageStream();
    } catch (_) {}
    await k?.dispose();
    await _tanima.close();
    await _olaylar.close();
  }
}
