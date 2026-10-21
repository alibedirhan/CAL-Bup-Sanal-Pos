import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import '../domain/kullanici.dart';
import 'ortak.dart';
import 'yonetim_carileri.dart';

class YonetimSayfasi extends StatefulWidget {
  const YonetimSayfasi({super.key, required this.yonetim});
  final YonetimPortu yonetim;
  @override
  State<YonetimSayfasi> createState() => _YonetimSayfasiState();
}

class _YonetimSayfasiState extends State<YonetimSayfasi> {
  late Future<List<Kullanici>> _liste = widget.yonetim.kullanicilar();
  String? _hata;
  bool _mesgul = false;
  void _yenile() => setState(() => _liste = widget.yonetim.kullanicilar());
  Future<void> _degistir(Kullanici k) async {
    if (_mesgul) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(k.aktif ? 'Erişim kapatılsın mı?' : 'Erişim açılsın mı?'),
        content: Text(
          k.aktif
              ? '${k.ad} hesabının carilere erişimi kapatılacak.'
              : '${k.ad} hesabı yeniden erişebilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await widget.yonetim.erisimDegistir(k, !k.aktif);
      if (mounted) _yenile();
    } catch (e) {
      if (mounted) {
        setState(
          () => _hata = e is PosHatasi ? e.mesaj : 'Erişim değiştirilemedi.',
        );
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kullanıcı yönetimi'),
      actions: [
        IconButton(
          onPressed: _yenile,
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _YeniHesap(yonetim: widget.yonetim),
          ),
        );
        if (mounted) _yenile();
      },
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Hesap aç'),
    ),
    body: FutureBuilder(
      future: _liste,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: _yenile,
              child: const Text('Liste okunamadı. Yeniden dene'),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            SinirliIcerik(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => YonetimCarileri(
                          port: widget.yonetim,
                          kullanicilar: s.data!,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Tüm cari atamaları'),
                  ),
                  const DurumNotu(
                    'Kullanıcılar yalnız kendilerine atanmış carileri görür. Bir cariyi aktarmak için cari profilindeki “Kullanıcıya ata” düğmesini kullan.',
                  ),
                  if (_hata != null) DurumNotu(_hata!, hata: true),
                  for (final k in s.data!)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(k.ad),
                      subtitle: Text(
                        '${k.eposta}\n${k.yonetici
                            ? 'Yönetici'
                            : k.aktif
                            ? 'Erişim açık'
                            : 'Erişim kapalı'}',
                      ),
                      trailing: k.yonetici
                          ? const Icon(Icons.admin_panel_settings_outlined)
                          : Switch(
                              value: k.aktif,
                              onChanged: _mesgul ? null : (_) => _degistir(k),
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _YeniHesap extends StatefulWidget {
  const _YeniHesap({required this.yonetim});
  final YonetimPortu yonetim;
  @override
  State<_YeniHesap> createState() => _YeniHesapState();
}

class _YeniHesapState extends State<_YeniHesap> {
  final _ad = TextEditingController(),
      _eposta = TextEditingController(),
      _parola = TextEditingController();
  bool _mesgul = false;
  String? _hata;
  @override
  void dispose() {
    _ad.dispose();
    _eposta.dispose();
    _parola.dispose();
    super.dispose();
  }

  Future<void> _ac() async {
    if (_mesgul) return;
    if (_ad.text.trim().length < 2 ||
        !_eposta.text.contains('@') ||
        _parola.text.length < 6) {
      setState(() => _hata = 'Ad, e-posta ve en az 6 karakterlik şifre yaz.');
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await widget.yonetim.hesapAc(_ad.text, _eposta.text, _parola.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hesap açıldı. Kullanıcı ilk girişten sonra şifresini değiştirebilir.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hata = e is PosHatasi ? e.mesaj : 'Hesap açılamadı.');
      }
    } finally {
      if (mounted) {
        _parola.clear();
        setState(() => _mesgul = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni kullanıcı hesabı')),
    body: ListView(
      children: [
        SinirliIcerik(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ad,
                enabled: !_mesgul,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Ad soyad'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _eposta,
                enabled: !_mesgul,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _parola,
                enabled: !_mesgul,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 128,
                decoration: const InputDecoration(
                  labelText: 'İlk giriş şifresi',
                ),
              ),
              const SizedBox(height: 16),
              const DurumNotu(
                'En az 6 karakter kullan. Şifreyi kullanıcıya ayrı bir kanaldan ilet; kullanıcı hesabından değiştirebilir. Yeni hesap yönetici yetkisi almaz.',
              ),
              if (_hata != null) ...[
                const SizedBox(height: 16),
                DurumNotu(_hata!, hata: true),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _mesgul ? null : _ac,
                child: Text(_mesgul ? 'Açılıyor…' : 'Hesabı aç'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
