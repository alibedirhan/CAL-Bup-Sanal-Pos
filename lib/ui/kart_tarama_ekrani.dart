import 'dart:async';
import 'package:flutter/material.dart';
import '../application/kart_tarama.dart';
import '../domain/kart_okuma.dart';
import 'ortak.dart';
import 'tema.dart';

/// Platformun kart okuma yolları (Android: NFC, kamera). Web'de yok.
class KartTarayicilari {
  const KartTarayicilari({required this.turler, required this.ac});

  /// Bu cihazda bulunan yollar (donanım).
  final Future<Set<TaramaTuru>> Function() turler;

  /// Okuma ekranını açar; okunan kart veya vazgeçilince `null`.
  final Future<OkunanKart?> Function(BuildContext context, TaramaTuru tur) ac;
}

/// Okuma ekranı: oturumu başlatır, durumu gösterir, okununca kartla kapanır.
/// Kapanırken donanım (kamera/NFC) her durumda bırakılır.
class KartTaramaEkrani extends StatefulWidget {
  const KartTaramaEkrani({
    super.key,
    required this.tur,
    required this.oturum,
    this.gorunum,
  });
  final TaramaTuru tur;
  final KartTaramaOturumu oturum;

  /// Kamera önizlemesi; NFC'de yok.
  final Widget? gorunum;
  @override
  State<KartTaramaEkrani> createState() => _KartTaramaEkraniState();
}

class _KartTaramaEkraniState extends State<KartTaramaEkrani>
    with WidgetsBindingObserver {
  StreamSubscription<TaramaOlayi>? _dinleme;
  TaramaNotu _not = const TaramaNotu('Hazırlanıyor…');
  bool get _nfc => widget.tur == TaramaTuru.nfc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dinleme = widget.oturum.olaylar.listen((o) {
      if (!mounted) return;
      switch (o) {
        case TaramaNotu():
          setState(() => _not = o);
        case TaramaOkundu(:final kart):
          Navigator.of(context).pop(kart);
      }
    });
    _baslat();
  }

  void _baslat() => unawaited(
    widget.oturum.baslat().catchError((Object _) {
      if (mounted) {
        setState(
          () => _not = const TaramaNotu('Okuma başlatılamadı.', hata: true),
        );
      }
    }),
  );

  /// Ayarlardan dönünce (NFC açıldı, izin verildi) yeniden denenir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _not.ayarlar) _baslat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dinleme?.cancel();
    unawaited(widget.oturum.kapat().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_nfc ? 'Temassız oku' : 'Kamerayla oku')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: widget.gorunum != null
                ? ClipRect(child: Center(child: widget.gorunum))
                : const Center(
                    child: Icon(
                      Icons.contactless_outlined,
                      size: 120,
                      color: PosRenk.vurgu,
                    ),
                  ),
          ),
          SinirliIcerik(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: DurumNotu(
                    _not.mesaj,
                    hata: _not.hata,
                    simge: _nfc
                        ? Icons.contactless_outlined
                        : Icons.photo_camera_outlined,
                  ),
                ),
                if (_not.ayarlar) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(widget.oturum.ayarlariAc()),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Ayarları aç'),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  _nfc
                      ? 'Yalnız kart numarası ve son kullanma okunur; ödeme yapılmaz. CVV okunmaz.'
                      : 'Görüntü kaydedilmez ve hiçbir yere gönderilmez; yazı bu cihazda okunur. CVV okunmaz.',
                  style: const TextStyle(fontSize: 12, color: PosRenk.ikincil),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
