import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import 'ortak.dart';
import 'tema.dart';

class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({
    super.key,
    required this.hesap,
    this.eposta,
    this.kilitli = false,
    this.giris,
  });
  final HesapPortu hesap;
  final String? eposta;
  final bool kilitli;
  final Future<void> Function(String parola)? giris;
  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  final _form = GlobalKey<FormState>();
  late final _eposta = TextEditingController(text: widget.eposta);
  final _parola = TextEditingController();
  // _denendi: ilk girişten sonra uyarılar yazdıkça güncellenir/kalkar.
  bool _mesgul = false, _goster = false, _denendi = false;
  String? _mesaj;
  bool _hata = false;
  @override
  void dispose() {
    _eposta.dispose();
    _parola.dispose();
    super.dispose();
  }

  Future<void> _islem(bool sifirla) async {
    if (_mesgul) return;
    if (!sifirla) {
      setState(() => _denendi = true);
      if (!_form.currentState!.validate()) return;
    }
    final eposta = _eposta.text.trim();
    if (sifirla && !eposta.contains('@')) {
      setState(() {
        _mesaj = 'Önce e-posta adresini yaz.';
        _hata = true;
      });
      return;
    }
    setState(() {
      _mesgul = true;
      _mesaj = null;
    });
    try {
      if (sifirla) {
        await widget.hesap.parolaSifirla(eposta);
        if (mounted) {
          setState(() {
            _hata = false;
            _mesaj =
                'Hesap uygunsa şifre yenileme bağlantısı e-posta adresine gönderildi. Gelen kutunu ve istenmeyen postayı kontrol et.';
          });
        }
      } else if (widget.giris != null) {
        await widget.giris!(_parola.text);
      } else {
        await widget.hesap.giris(eposta, _parola.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = true;
          _mesaj = e is PosHatasi
              ? e.mesaj
              : 'Giriş yapılamadı. Yeniden deneyin.';
        });
      }
    } finally {
      if (mounted) {
        // Şifre kutusu güvenlik için boşalır; boş kutu ayrıca uyarı vermesin.
        _parola.clear();
        setState(() {
          _mesgul = false;
          _denendi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: SinirliIcerik(
            child: AutofillGroup(
              child: Form(
                key: _form,
                autovalidateMode: _denendi
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      size: 52,
                      color: PosRenk.vurgu,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.kilitli
                          ? 'Tekrar hoş geldin.'
                          : 'Sanal POS’a\nhoş geldin.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.kilitli
                          ? 'Çalışma alanını açmak için şifreni doğrula.'
                          : 'Yönetici tarafından açılan hesabınla giriş yap.',
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _eposta,
                      enabled: !_mesgul && !widget.kilitli,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (v) => (v?.contains('@') ?? false)
                          ? null
                          : 'E-posta adresini kontrol et.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _parola,
                      enabled: !_mesgul,
                      obscureText: !_goster,
                      autofillHints: const [AutofillHints.password],
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.go,
                      onFieldSubmitted: (_) => _islem(false),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        suffixIcon: IconButton(
                          tooltip: _goster ? 'Şifreyi gizle' : 'Şifreyi göster',
                          onPressed: () => setState(() => _goster = !_goster),
                          icon: Icon(
                            _goster
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v?.isNotEmpty ?? false) ? null : 'Şifreni yaz.',
                    ),
                    const SizedBox(height: 20),
                    if (_mesaj != null) ...[
                      DurumNotu(_mesaj!, hata: _hata),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _mesgul ? null : () => _islem(false),
                      child: Text(
                        _mesgul
                            ? 'Kontrol ediliyor…'
                            : widget.kilitli
                            ? 'Kilidi aç'
                            : 'Giriş yap',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _mesgul ? null : () => _islem(true),
                      child: const Text('Şifremi unuttum'),
                    ),
                    if (widget.kilitli)
                      TextButton(
                        onPressed: _mesgul ? null : widget.hesap.cikis,
                        child: const Text('Başka hesapla giriş yap'),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'BUP Sanal POS · Yalnız yetkili kullanıcılar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: PosRenk.ikincil),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
