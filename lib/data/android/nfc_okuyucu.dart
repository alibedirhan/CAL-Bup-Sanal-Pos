import 'dart:async';
import 'package:flutter/services.dart';
import '../../application/kart_tarama.dart';
import '../../domain/emv.dart';

/// Temassız kart okuma (Kotlin `NfcKanali.kt`). Kart dokununca EMV okuması
/// (`domain/emv.dart`) bu kanal üzerinden yürür; okunan forma yazılır.
class NfcOkuyucu implements KartTaramaOturumu {
  NfcOkuyucu({required this.saat, MethodChannel? kanal})
    : _kanal = kanal ?? const MethodChannel('bup/nfc');
  final DateTime Function() saat;
  final MethodChannel _kanal;
  final _olaylar = StreamController<TaramaOlayi>.broadcast();
  bool _okuyor = false, _kapali = false;

  static const _yaklastir = TaramaNotu(
    'Kartı telefonun arkasına yaklaştır ve okunana kadar tut.',
  );

  @override
  Stream<TaramaOlayi> get olaylar => _olaylar.stream;

  void _bildir(TaramaOlayi o) {
    if (!_kapali) _olaylar.add(o);
  }

  @override
  Future<void> baslat() async {
    _kanal.setMethodCallHandler(_kartGeldi);
    final d = await _kanal.invokeMapMethod<String, Object?>('durum') ?? {};
    if (d['var'] != true) {
      return _bildir(
        const TaramaNotu('Bu cihazda temassız (NFC) okuma yok.', hata: true),
      );
    }
    if (d['acik'] != true) {
      return _bildir(
        const TaramaNotu(
          'NFC kapalı. Ayarlardan NFC’yi açıp bu ekrana dön.',
          hata: true,
          ayarlar: true,
        ),
      );
    }
    await _kanal.invokeMethod<void>('baslat');
    _bildir(_yaklastir);
  }

  /// Ayarlardan dönüşte NFC açılmış olabilir: ekran yeniden başlatır.
  @override
  Future<void> ayarlariAc() => _kanal.invokeMethod<void>('ayarlar');

  Future<Object?> _kartGeldi(MethodCall c) async {
    if (c.method == 'kart_degil') {
      _bildir(
        const TaramaNotu(
          'Bu bir banka kartı değil ya da temassız değil.',
          hata: true,
        ),
      );
    } else if (c.method == 'kart' && !_okuyor) {
      _okuyor = true;
      _bildir(const TaramaNotu('Okunuyor… Kartı çekme.'));
      try {
        final k = await emvKartOku(_gonder, simdi: saat());
        _bildir(TaramaOkundu(k));
      } on EmvHatasi catch (e) {
        _bildir(
          TaramaNotu(switch (e.kod) {
            'veri_yok' =>
              'Kart numarasını temassız vermiyor. Kamerayla oku ya da elle yaz.',
            _ => 'Kart okunamadı. Kartı biraz kaydırıp yeniden yaklaştır.',
          }, hata: true),
        );
      } catch (_) {
        _bildir(
          const TaramaNotu(
            'Kart erken çekildi. Yeniden yaklaştır ve okunana kadar tut.',
            hata: true,
          ),
        );
      } finally {
        _okuyor = false;
      }
    }
    return null;
  }

  Future<Uint8List> _gonder(Uint8List komut) async =>
      await _kanal.invokeMethod<Uint8List>('apdu', {'komut': komut}) ??
      (throw const EmvHatasi('yanit'));

  @override
  Future<void> kapat() async {
    if (_kapali) return;
    _kapali = true;
    _kanal.setMethodCallHandler(null);
    try {
      await _kanal.invokeMethod<void>('bitir');
    } catch (_) {}
    await _olaylar.close();
  }
}
