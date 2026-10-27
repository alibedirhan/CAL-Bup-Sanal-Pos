import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/pin_kapisi.dart';
import '../domain/uygulama_pin.dart';
import 'ortak.dart';

/// Uygulama PIN'i penceresi. `null`: kişi vazgeçti.
Future<String?> pinPenceresiAc(BuildContext context, PinIstegi istek) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinPenceresi(istek),
    );

class _PinPenceresi extends StatefulWidget {
  const _PinPenceresi(this.istek);
  final PinIstegi istek;
  @override
  State<_PinPenceresi> createState() => _PinPenceresiState();
}

class _PinPenceresiState extends State<_PinPenceresi> {
  final _pin = TextEditingController(), _tekrar = TextEditingController();
  String? _hata;
  bool get _kur => widget.istek.tur == PinTuru.kur;

  @override
  void dispose() {
    _pin.dispose();
    _tekrar.dispose();
    super.dispose();
  }

  void _tamam() {
    final hata = _kur
        ? UygulamaPin.yeniPinHatasi(_pin.text, _tekrar.text)
        : UygulamaPin.bicimli(_pin.text)
        ? null
        : 'PIN 6 rakam olmalı.';
    if (hata != null) return setState(() => _hata = hata);
    Navigator.of(context).pop(_pin.text);
  }

  Widget _alan(TextEditingController c, String etiket, {bool odak = false}) =>
      TextField(
        controller: c,
        autofocus: odak,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: UygulamaPin.uzunluk,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(labelText: etiket, counterText: ''),
        onSubmitted: (_) => _tamam(),
      );

  @override
  Widget build(BuildContext context) {
    final not = _hata ?? widget.istek.not;
    return AlertDialog(
      title: Text(_kur ? 'Uygulama PIN’i belirle' : 'Uygulama PIN’i'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _kur
                  ? 'Bu telefonda ekran kilidi yok. Kartlarını korumak için 6 '
                        'haneli bir PIN belirle; kartı görüntülerken ve '
                        'doldururken sorulur. PIN’i unutursan kartları yeniden '
                        'eklemen gerekir.'
                  : 'Kart bilgisini açmak için uygulama PIN’ini yaz.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            _alan(_pin, 'PIN', odak: true),
            if (_kur) _alan(_tekrar, 'PIN (tekrar)'),
            if (not != null) DurumNotu(not, hata: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _tamam,
          child: Text(_kur ? 'PIN’i kaydet' : 'Aç'),
        ),
      ],
    );
  }
}
