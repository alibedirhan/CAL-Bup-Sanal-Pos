import 'package:flutter/material.dart';
import '../application/kart_tarama.dart';
import '../domain/kart_okuma.dart';
import 'kart_tarama_ekrani.dart';
import 'ortak.dart';
import 'tema.dart';

/// Telefonun yazı tanımasıyla (iPhone Canlı Metin / "Metni Tara", Android
/// Lens) kopyalanan kart yazısı buraya yapıştırılır. Metin hemen ayrıştırılıp
/// kutudan silinir; saklanmaz, gönderilmez. Yalnız emin olunan alanlar döner.
/// Android'de ayrıca temassız (NFC) ve kamerayla okuma düğmeleri ([tarayici]).
class KartOkumaKutusu extends StatefulWidget {
  const KartOkumaKutusu({
    super.key,
    required this.etkin,
    required this.simdi,
    required this.okundu,
    this.tarayici,
  });
  final bool etkin;
  final KartTarayicilari? tarayici;
  final DateTime Function() simdi;
  final ValueChanged<OkunanKart> okundu;
  @override
  State<KartOkumaKutusu> createState() => _KartOkumaKutusuState();
}

class _KartOkumaKutusuState extends State<KartOkumaKutusu> {
  final _metin = TextEditingController();
  String? _sonuc;
  bool _hata = false;
  Set<TaramaTuru> _turler = const {};

  @override
  void initState() {
    super.initState();
    widget.tarayici?.turler().then((t) {
      if (mounted) setState(() => _turler = t);
    }, onError: (Object _) {});
  }

  void _degisti(String deger) {
    if (deger.trim().length < 8) return;
    final k = kartMetniniOku(deger, simdi: widget.simdi());
    _metin.clear();
    _goster(k);
  }

  Future<void> _tara(TaramaTuru tur) async {
    final k = await widget.tarayici!.ac(context, tur);
    if (mounted && k != null) _goster(k);
  }

  void _goster(OkunanKart k) {
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
      if (_turler.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_turler.contains(TaramaTuru.nfc))
              OutlinedButton.icon(
                onPressed: widget.etkin ? () => _tara(TaramaTuru.nfc) : null,
                icon: const Icon(Icons.contactless_outlined),
                label: const Text('Temassız oku'),
              ),
            if (_turler.contains(TaramaTuru.kamera))
              OutlinedButton.icon(
                onPressed: widget.etkin ? () => _tara(TaramaTuru.kamera) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamerayla oku'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Numara ve son kullanma kutulara yazılır; karşılaştırıp kaydet. CVV okunmaz.',
          style: TextStyle(fontSize: 12, color: PosRenk.ikincil),
        ),
      ],
      // Tarayıcı sürümü: telefonun yazı tanımasıyla kopyalanan yazı yapıştırılır.
      // Android'de bunun yerine yukarıdaki okuma düğmeleri var.
      if (widget.tarayici == null)
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
