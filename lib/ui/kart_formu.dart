import 'package:flutter/material.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/kart_bilgileri.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';

Future<void> kartFormunuAc(
  BuildContext context,
  OturumModeli model, {
  KartOzeti? kart,
}) {
  final cari = model.profil!.cari;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _KartFormu(model: model, cari: cari, kart: kart),
  );
}

class _KartFormu extends StatefulWidget {
  const _KartFormu({required this.model, required this.cari, this.kart});
  final OturumModeli model;
  final Cari cari;
  final KartOzeti? kart;
  @override
  State<_KartFormu> createState() => _KartFormuState();
}

class _KartFormuState extends State<_KartFormu> {
  final _form = GlobalKey<FormState>();
  late final _ad = TextEditingController(text: widget.kart?.ad);
  final _numara = TextEditingController(),
      _sahibi = TextEditingController(),
      _telefon = TextEditingController();
  late final _ay = TextEditingController(text: widget.kart?.ay.toString());
  late final _yil = TextEditingController(text: widget.kart?.yil.toString());
  bool _mesgul = false, _yukleniyor = false, _goster = false, _onay = false;
  String? _hata, _bilgi;
  @override
  void initState() {
    super.initState();
    widget.model.addListener(_erisimDegisti);
    if (widget.kart != null) {
      _yukleniyor = true;
      _yukle();
    }
  }

  void _erisimDegisti() {
    if (widget.model.kilitli ||
        widget.model.profil?.cari.id != widget.cari.id) {
      _numara.clear();
      _sahibi.clear();
      _telefon.clear();
      _goster = false;
    }
  }

  Future<void> _yukle() async {
    try {
      final b = await widget.model.kartBilgileri(widget.kart!);
      if (!mounted) return;
      if (b == null) {
        _bilgi =
            'Bu cihazda tam kart bilgisi yok. Kart numarasını yazarak bu cihaza da ekleyebilirsin.';
      } else {
        _numara.text = b.numara;
        _sahibi.text = b.sahibi;
        _telefon.text = b.telefon;
      }
    } catch (e) {
      if (mounted) {
        _hata = e is PosHatasi ? e.mesaj : 'Kart açılamadı. Yeniden dene.';
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_erisimDegisti);
    for (final c in [_ad, _numara, _sahibi, _telefon, _ay, _yil]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul || _yukleniyor || !_form.currentState!.validate()) return;
    if (!_onay) {
      setState(
        () => _hata = 'Kartı ve bağlı cariyi kontrol edip kutuyu işaretle.',
      );
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final bilgiler = KartBilgileri(
        numara: _numara.text,
        sahibi: _sahibi.text,
        telefon: _telefon.text,
      );
      final kart = KartOzeti(
        id: widget.kart?.id ?? 'kart-${DateTime.now().microsecondsSinceEpoch}',
        cariId: widget.cari.id,
        ad: _ad.text,
        sonDort: bilgiler.sonDort,
        ay: int.tryParse(_ay.text) ?? 0,
        yil: int.tryParse(_yil.text) ?? 0,
      );
      final tamam = await widget.model.kartKaydet(kart, bilgiler: bilgiler);
      if (!mounted) return;
      if (tamam) {
        Navigator.pop(context);
      } else {
        setState(
          () => _hata = widget.model.hatayiAl() ?? 'Kart kaydedilemedi.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _hata = e is PosHatasi
              ? e.mesaj
              : 'Alanları kontrol edip yeniden dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  String? _numaraDenetle(String? value) {
    try {
      kartNumarasi(value ?? '');
      return null;
    } on PosHatasi catch (e) {
      return e.mesaj;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      if (widget.model.kilitli ||
          widget.model.profil?.cari.id != widget.cari.id) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cari erişimi değişti. Formu kapatıp güncel cariyi yeniden aç.',
          ),
        );
      }
      final aktif = !_mesgul && !_yukleniyor;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: SinirliIcerik(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.kart == null ? 'Kart ekle' : 'Kartı düzenle',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Bu kart ${widget.cari.ad} carisine aittir.'),
                  const SizedBox(height: 16),
                  const DurumNotu(
                    'Tam kart bilgileri yalnız bu tarayıcıda şifreli tutulur. Tarayıcı verileri silinirse yeniden eklemen gerekir. CVV ödeme ekranında girilir.',
                  ),
                  const SizedBox(height: 20),
                  if (_yukleniyor) const LinearProgressIndicator(),
                  if (_bilgi != null) ...[
                    DurumNotu(_bilgi!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _ad,
                    enabled: aktif,
                    maxLength: 60,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kart adı',
                      hintText: 'İş kartı',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Karta en az 2 karakterlik bir ad ver.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numara,
                    enabled: aktif,
                    maxLength: 23,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    obscureText: !_goster,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Kart numarası',
                      suffixIcon: IconButton(
                        onPressed: aktif
                            ? () => setState(() => _goster = !_goster)
                            : null,
                        tooltip: _goster
                            ? 'Kart numarasını gizle'
                            : 'Kart numarasını göster',
                        icon: Icon(
                          _goster
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: _numaraDenetle,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sahibi,
                    enabled: aktif,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kart üzerindeki ad (isteğe bağlı)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ay,
                          enabled: aktif,
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Ay',
                            hintText: 'AA',
                          ),
                          validator: (v) =>
                              (int.tryParse(v ?? '') ?? 0) < 1 ||
                                  (int.tryParse(v ?? '') ?? 0) > 12
                              ? '01–12 yaz.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _yil,
                          enabled: aktif,
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Yıl',
                            hintText: 'YYYY',
                          ),
                          validator: (v) =>
                              (int.tryParse(v ?? '') ?? 0) < 2000 ||
                                  (int.tryParse(v ?? '') ?? 0) > 2199
                              ? 'Dört haneli yıl yaz.'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefon,
                    enabled: aktif,
                    maxLength: 24,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'İletişim telefonu (isteğe bağlı)',
                      helperText: 'Bankanın SMS hedefini değiştirmez.',
                    ),
                    validator: (v) {
                      try {
                        kartTelefonu(v ?? '');
                        return null;
                      } on PosHatasi catch (e) {
                        return e.mesaj;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _onay,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Kartı ve bu cari altında saklamayı kontrol ettim.',
                    ),
                    onChanged: aktif
                        ? (v) => setState(() => _onay = v ?? false)
                        : null,
                  ),
                  if (_hata != null) ...[
                    DurumNotu(_hata!, hata: true),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: aktif ? _kaydet : null,
                    child: Text(_mesgul ? 'Kaydediliyor…' : 'Kartı kaydet'),
                  ),
                  TextButton(
                    onPressed: _mesgul ? null : () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> kartSilmeOnayi(
  BuildContext context,
  OturumModeli model,
  KartOzeti kart,
) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kart silinsin mi?'),
      content: Text(
        '${kart.ad} · ${kart.maske} kaydı ve bu cihazdaki tam bilgileri kaldırılacak.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay == true) await model.kartSil(kart.id);
}
