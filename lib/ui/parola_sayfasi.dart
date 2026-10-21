import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import 'ortak.dart';

class ParolaSayfasi extends StatefulWidget {
  const ParolaSayfasi({super.key, required this.hesap});
  final HesapPortu hesap;
  @override
  State<ParolaSayfasi> createState() => _ParolaSayfasiState();
}

class _ParolaSayfasiState extends State<ParolaSayfasi> {
  final _eski = TextEditingController(),
      _yeni = TextEditingController(),
      _tekrar = TextEditingController();
  bool _mesgul = false;
  String? _hata;
  @override
  void dispose() {
    _eski.dispose();
    _yeni.dispose();
    _tekrar.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    if (_yeni.text.length < 6 ||
        _yeni.text.length > 128 ||
        _yeni.text != _tekrar.text) {
      setState(
        () => _hata =
            'Yeni şifre 6–128 karakter olmalı ve iki alanda aynı yazılmalı.',
      );
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await widget.hesap.parolaDegistir(_eski.text, _yeni.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Şifren güncellendi.')));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _hata = e is PosHatasi ? e.mesaj : 'Şifre değiştirilemedi.',
        );
      }
    } finally {
      if (mounted) {
        _eski.clear();
        _yeni.clear();
        _tekrar.clear();
        setState(() => _mesgul = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Şifreni değiştir')),
    body: ListView(
      children: [
        SinirliIcerik(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in [
                (_eski, 'Mevcut şifre'),
                (_yeni, 'Yeni şifre'),
                (_tekrar, 'Yeni şifre tekrar'),
              ]) ...[
                TextField(
                  controller: field.$1,
                  obscureText: true,
                  enabled: !_mesgul,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: field.$2),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'En az 6 karakter kullan. Daha önce kullanmadığın bir şifre seç.',
              ),
              const SizedBox(height: 16),
              if (_hata != null) DurumNotu(_hata!, hata: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _mesgul ? null : _kaydet,
                child: Text(_mesgul ? 'Güncelleniyor…' : 'Şifreyi güncelle'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
