import 'package:flutter/material.dart';
import '../application/tahsilat_servisi.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/tahsilat.dart';
import 'ortak.dart';
import 'tema.dart';

/// DenizPay sonuç ekranına bakarak elle kayıt (yer imi kullanılamadığında).
/// Kaydedilince alttaki ekranda kısa bir bildirim gösterilir.
Future<void> islemFormunuAc(
  BuildContext context,
  TahsilatServisi servis,
  CariProfili profil,
) async {
  final kayit = await altPencereAc<IslemKaydi>(
    context,
    (_) => IslemFormu(servis: servis, profil: profil),
  );
  if (kayit == null || !context.mounted) return;
  final i = kayit.islem;
  final tutar = i.tutarKurus == null ? i.tutarMetni : tutarYaz(i.tutarKurus!);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        kayit.zatenVardi
            ? 'Bu ödeme zaten kayıtlı: ${i.cariAd} · ${saatYaz(i.zaman!)}.'
            : 'Kaydedildi: ${i.cariAd} · $tutar · ${i.basarili ? 'başarılı' : 'başarısız'}.',
      ),
    ),
  );
}

class IslemFormu extends StatefulWidget {
  const IslemFormu({super.key, required this.servis, required this.profil});
  final TahsilatServisi servis;
  final CariProfili profil;
  @override
  State<IslemFormu> createState() => _IslemFormuState();
}

class _IslemFormuState extends State<IslemFormu> {
  final _form = GlobalKey<FormState>();
  final _posNo = TextEditingController();
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  IslemSonucu _sonuc = IslemSonucu.basarili;
  String _kart = '';
  String? _hata;
  bool _kaydediliyor = false, _denendi = false;

  @override
  void dispose() {
    _posNo.dispose();
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;
    setState(() => _denendi = true);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      final kayit = await widget.servis.elleKaydet(
        cari: widget.profil.cari,
        sonuc: _sonuc,
        posSiparisNo: _posNo.text,
        tutarMetni: _tutar.text,
        aciklama: _aciklama.text,
        kartSonDort: _kart,
      );
      if (mounted) Navigator.pop(context, kayit);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kaydediliyor = false;
        _hata = e is PosHatasi
            ? e.mesaj
            : 'Kaydedilemedi. Bağlantını kontrol edip yeniden dene.';
      });
    }
  }

  String? _posNoKontrol(String? v) {
    try {
      posNoDuzelt(v ?? '');
      return null;
    } on PosHatasi catch (e) {
      return e.mesaj;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profil;
    final tutar = tutarCoz(_tutar.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: SinirliIcerik(
          child: Form(
            key: _form,
            autovalidateMode: _denendi
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ödeme sonucunu kaydet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text('${p.cari.ad} · VKN / TC ${p.cari.kimlikNo}'),
                const SizedBox(height: 16),
                SegmentedButton<IslemSonucu>(
                  segments: const [
                    ButtonSegment(
                      value: IslemSonucu.basarili,
                      label: Text('Başarılı'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: IslemSonucu.hata,
                      label: Text('Başarısız'),
                      icon: Icon(Icons.cancel_outlined),
                    ),
                  ],
                  selected: {_sonuc},
                  onSelectionChanged: _kaydediliyor
                      ? null
                      : (s) => setState(() => _sonuc = s.single),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _posNo,
                  enabled: !_kaydediliyor,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Pos Sipariş Numarası',
                    hintText: 'VP…',
                  ),
                  validator: _posNoKontrol,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tutar,
                  enabled: !_kaydediliyor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tutar',
                    hintText: '4500 veya 45678,90',
                    suffixText: 'TL',
                    helperText: tutar == null ? null : tutarYaz(tutar),
                  ),
                  validator: (v) => tutarCoz(v ?? '') == null
                      ? 'Tutarı DenizPay ekranındaki gibi yaz.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _aciklama,
                  enabled: !_kaydediliyor,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: _sonuc == IslemSonucu.hata
                        ? 'Hata açıklaması'
                        : 'Açıklama (isteğe bağlı)',
                    hintText: _sonuc == IslemSonucu.hata
                        ? 'ör. 3D Şifresi Yanlış.'
                        : null,
                    counterText: '',
                  ),
                  validator: (v) =>
                      _sonuc == IslemSonucu.hata && (v ?? '').trim().isEmpty
                      ? 'Hata ekranındaki açıklamayı yaz.'
                      : null,
                ),
                if (p.kartlar.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _kart,
                    decoration: const InputDecoration(labelText: 'Kart'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Belirtilmedi'),
                      ),
                      for (final k in {for (final k in p.kartlar) k.sonDort})
                        DropdownMenuItem(value: k, child: Text('•••• $k')),
                    ],
                    onChanged: _kaydediliyor
                        ? null
                        : (v) => setState(() => _kart = v ?? ''),
                  ),
                ],
                const SizedBox(height: 16),
                const DurumNotu(
                  'Bilgileri DenizPay’in Onay Formu / Hata Formu ekranından yaz. '
                  'Kayıt sonradan değiştirilemez; aynı Pos Sipariş Numarası ikinci '
                  'kez kaydedilmez.',
                ),
                if (_hata != null) ...[
                  const SizedBox(height: 12),
                  DurumNotu(_hata!, hata: true),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _kaydediliyor ? null : _kaydet,
                  child: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Kaydet'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _kaydediliyor
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Vazgeç'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kaydeden: ${widget.servis.kullaniciAdi}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: PosRenk.ikincil),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
