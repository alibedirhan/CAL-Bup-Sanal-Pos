import 'package:flutter/material.dart';
import '../domain/modeller.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';

Future<void> cariFormunuAc(
  BuildContext context,
  OturumModeli model, {
  Cari? cari,
}) => altPencereAc<void>(context, (_) => CariFormu(model: model, cari: cari));

class CariFormu extends StatefulWidget {
  const CariFormu({super.key, required this.model, this.cari});
  final OturumModeli model;
  final Cari? cari;
  @override
  State<CariFormu> createState() => _CariFormuState();
}

class _CariFormuState extends State<CariFormu> {
  final _form = GlobalKey<FormState>();
  late final _ad = TextEditingController(text: widget.cari?.ad);
  late final _kimlik = TextEditingController(text: widget.cari?.kimlikNo);
  String? _hata;
  // İlk kayıt denemesinden sonra uyarılar yazdıkça güncellenir/kalkar.
  bool _kaydediliyor = false, _denendi = false;
  @override
  void dispose() {
    _ad.dispose();
    _kimlik.dispose();
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
    final tamam = await widget.model.cariKaydet(
      _ad.text,
      eski: widget.cari,
      kimlikNo: _kimlik.text.trim(),
    );
    if (!mounted) return;
    if (tamam) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _kaydediliyor = false;
      _hata = widget.model.hatayiAl() ?? 'İşlem tamamlanamadı.';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
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
                widget.cari == null ? 'Yeni cari' : 'Cariyi düzenle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.model.deneme
                    ? 'Bu kayıt deneme oturumuna eklenir.'
                    : 'Kayıt hesabına atanır ve sunucuda saklanır.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ad,
                enabled: !_kaydediliyor,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Cari adı',
                  hintText: 'Örnek Yeni Market',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 2
                    ? 'En az 2 karakterlik bir ad yazın.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kimlik,
                enabled: !_kaydediliyor,
                maxLength: 11,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _kaydet(),
                decoration: const InputDecoration(
                  labelText: 'Vergi / TC kimlik numarası',
                  helperText: 'POS girişi için 10 veya 11 rakam yaz.',
                ),
                validator: (v) =>
                    RegExp(r'^[0-9]{10,11}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : '10 veya 11 rakam yaz.',
              ),
              if (_hata != null) ...[
                const SizedBox(height: 12),
                DurumNotu(_hata!, hata: true),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                child: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Cariyi kaydet'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _kaydediliyor ? null : () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
