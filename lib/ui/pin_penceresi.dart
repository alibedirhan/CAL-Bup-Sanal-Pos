import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/pin_kapisi.dart';
import '../domain/uygulama_pin.dart';
import 'tema.dart';

/// Uygulama PIN'i ekranı (tam ekran, kendi rakam tuşlarıyla; sistem klavyesi
/// açılmaz, küçük ekranda sıkışmaz). 6. rakamda kendiliğinden ilerler. Yeni
/// PIN iki adımda alınır (yaz, tekrar yaz). `null`: kişi vazgeçti.
Future<String?> pinPenceresiAc(BuildContext context, PinIstegi istek) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PinEkrani(istek),
      ),
    );

class _PinEkrani extends StatefulWidget {
  const _PinEkrani(this.istek);
  final PinIstegi istek;
  @override
  State<_PinEkrani> createState() => _PinEkraniState();
}

class _PinEkraniState extends State<_PinEkrani> {
  String _girilen = '';
  String? _ilk; // Yeni PIN'in ilk yazılışı (tekrar adımında dolu).
  late String? _not = widget.istek.not;
  bool get _kur => widget.istek.tur == PinTuru.kur;

  void _rakam(String r) {
    if (_girilen.length >= UygulamaPin.uzunluk) return;
    HapticFeedback.selectionClick();
    setState(() {
      _girilen += r;
      if (_girilen.length == 1) _not = null;
    });
    if (_girilen.length == UygulamaPin.uzunluk) _tamam();
  }

  void _sil() {
    if (_girilen.isEmpty) return;
    setState(() => _girilen = _girilen.substring(0, _girilen.length - 1));
  }

  void _tamam() {
    final pin = _girilen;
    if (!_kur) return Navigator.of(context).pop(pin);
    final ilk = _ilk;
    if (ilk == null) {
      // İlk yazılış: kolay PIN hemen söylenir.
      final hata = UygulamaPin.yeniPinHatasi(pin, pin);
      return setState(() {
        _girilen = '';
        if (hata != null) {
          _not = hata;
        } else {
          _ilk = pin;
          _not = null;
        }
      });
    }
    if (UygulamaPin.yeniPinHatasi(ilk, pin) != null) {
      return setState(() {
        _girilen = '';
        _ilk = null;
        _not = 'İki PIN aynı değil. Baştan yaz.';
      });
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final baslik = !_kur
        ? 'PIN’ini yaz'
        : _ilk == null
        ? 'Yeni PIN belirle'
        : 'Aynı PIN’i tekrar yaz';
    final aciklama = !_kur
        ? 'Kart bilgisini açmak için 6 haneli uygulama PIN’in.'
        : _ilk == null
        ? 'Bu cihazda ekran kilidi yok; kartlarını 6 haneli bir PIN korur. '
              'Unutursan kartları yeniden eklemen gerekir.'
        : 'Doğrulamak için bir kez daha.';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Vazgeç',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Uygulama PIN’i'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, alan) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: alan.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 40,
                          color: PosRenk.vurgu,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          baslik,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: PosRenk.metin,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          aciklama,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: PosRenk.ikincil,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _Noktalar(_girilen.length),
                        // Not alanı sabit yükseklikte: mesaj gelince tuşlar kaymaz.
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _not ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: PosRenk.hata,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _TusTakimi(
                      rakam: _rakam,
                      sil: _sil,
                      silinebilir: _girilen.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Noktalar extends StatelessWidget {
  const _Noktalar(this.dolu);
  final int dolu;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$dolu / ${UygulamaPin.uzunluk} rakam yazıldı',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < UygulamaPin.uzunluk; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < dolu ? PosRenk.vurgu : Colors.transparent,
              border: Border.all(color: PosRenk.vurgu, width: 2),
            ),
          ),
      ],
    ),
  );
}

class _TusTakimi extends StatelessWidget {
  const _TusTakimi({
    required this.rakam,
    required this.sil,
    required this.silinebilir,
  });
  final ValueChanged<String> rakam;
  final VoidCallback sil;
  final bool silinebilir;

  Widget _tus(String r) => _Tus(
    key: ValueKey('pin-$r'),
    etiket: r,
    onPressed: () => rakam(r),
    child: Text(
      r,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
    ),
  );

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 320),
    child: Column(
      children: [
        for (final satir in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final r in satir) _tus(r)]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            _tus('0'),
            _Tus(
              key: const ValueKey('pin-sil'),
              etiket: 'Son rakamı sil',
              onPressed: silinebilir ? sil : null,
              child: const Icon(Icons.backspace_outlined, size: 26),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Tus extends StatelessWidget {
  const _Tus({
    super.key,
    required this.etiket,
    required this.onPressed,
    required this.child,
  });
  final String etiket;
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: etiket,
        excludeSemantics: true,
        child: SizedBox(
          height: 64,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: PosRenk.metin,
              backgroundColor: onPressed == null
                  ? Colors.transparent
                  : PosRenk.zemin,
              shape: const StadiumBorder(),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
