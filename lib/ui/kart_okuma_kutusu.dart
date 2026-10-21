import 'package:flutter/material.dart';
import '../domain/kart_okuma.dart';
import 'ortak.dart';

/// Telefonun yazı tanımasıyla (iPhone Canlı Metin / "Metni Tara", Android
/// Lens) kopyalanan kart yazısı buraya yapıştırılır. Metin hemen ayrıştırılıp
/// kutudan silinir; saklanmaz, gönderilmez. Yalnız emin olunan alanlar döner.
class KartOkumaKutusu extends StatefulWidget {
  const KartOkumaKutusu({
    super.key,
    required this.etkin,
    required this.simdi,
    required this.okundu,
  });
  final bool etkin;
  final DateTime Function() simdi;
  final ValueChanged<OkunanKart> okundu;
  @override
  State<KartOkumaKutusu> createState() => _KartOkumaKutusuState();
}

class _KartOkumaKutusuState extends State<KartOkumaKutusu> {
  final _metin = TextEditingController();
  String? _sonuc;
  bool _hata = false;

  void _degisti(String deger) {
    if (deger.trim().length < 8) return;
    final k = kartMetniniOku(deger, simdi: widget.simdi());
    _metin.clear();
    final bulunan = [
      if (k.numara != null) '•••• ${k.numara!.substring(k.numara!.length - 4)}',
      if (k.ay != null) '${k.ay.toString().padLeft(2, '0')} / ${k.yil}',
      if (k.ad != null) k.ad!,
    ];
    final eksik = [
      if (k.numara == null) 'kart numarası',
      if (k.ay == null) 'son kullanma',
      if (k.ad == null) 'kart üzerindeki ad',
    ];
    setState(() {
      _hata = k.bos;
      _sonuc = k.bos
          ? 'Kart bilgisi okunamadı. Alanları elle yaz.'
          : 'Yazıldı: ${bulunan.join(' · ')}. Kutuları kartla karşılaştır.'
                '${eksik.isEmpty ? '' : ' Okunamayan (elle yaz): ${eksik.join(', ')}.'}';
    });
    if (!k.bos) widget.okundu(k);
  }

  @override
  void dispose() {
    _metin.clear();
    _metin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _metin,
        enabled: widget.etkin,
        minLines: 1,
        maxLines: 3,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        // Tarayıcının kart önerisi bu kutuya değil, asıl kart kutularına gelir.
        autofillHints: null,
        onChanged: _degisti,
        decoration: const InputDecoration(
          labelText: 'Karttan oku (isteğe bağlı)',
          prefixIcon: Icon(Icons.document_scanner_outlined),
          helperText:
              'Kameranın yazı tanımasıyla kart yazısını kopyalayıp buraya yapıştır. CVV okunmaz.',
          helperMaxLines: 3,
        ),
      ),
      if (_sonuc != null) ...[
        const SizedBox(height: 8),
        DurumNotu(_sonuc!, hata: _hata),
      ],
    ],
  );
}
