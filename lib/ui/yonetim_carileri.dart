import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../domain/kullanici.dart';
import '../domain/modeller.dart';
import '../domain/hata.dart';
import 'ortak.dart';

class YonetimCarileri extends StatefulWidget {
  const YonetimCarileri({
    super.key,
    required this.port,
    required this.kullanicilar,
  });
  final YonetimPortu port;
  final List<Kullanici> kullanicilar;
  @override
  State<YonetimCarileri> createState() => _YonetimCarileriState();
}

class _YonetimCarileriState extends State<YonetimCarileri> {
  late Future<List<CariOzeti>> _liste = widget.port.cariler();
  bool _mesgul = false;
  String? _hata;
  Future<void> _ata(Cari cari) async {
    if (_mesgul) return;
    final secim = await showDialog<Kullanici>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cariyi yeniden ata'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cari.ad} için yeni kullanıcıyı seç.'),
                for (final k in widget.kullanicilar.where(
                  (k) => k.aktif && k.id != cari.sahipId,
                ))
                  ListTile(
                    title: Text(k.ad),
                    subtitle: Text(k.eposta),
                    onTap: () => Navigator.pop(context, k),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
    if (secim == null || !mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atamayı onayla'),
        content: Text(
          '${cari.ad}, ${secim.ad} kullanıcısına atanacak. Önceki kullanıcının erişimi kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ata'),
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
      await widget.port.ata(cari.id, cari.surum, secim.id);
      if (mounted) setState(() => _liste = widget.port.cariler());
    } catch (e) {
      if (mounted) {
        setState(
          () => _hata = e is PosHatasi
              ? e.mesaj
              : 'Atama yapılamadı. Yenileyip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cari atamaları'),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => setState(() => _liste = widget.port.cariler()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder(
      future: _liste,
      builder: (context, s) {
        if (s.hasError) {
          return const Center(
            child: Text('Atamalar okunamadı. Yenile düğmesini kullan.'),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            SinirliIcerik(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DurumNotu(
                    'Bu yönetici ekranı tüm aktif cari atamalarını gösterir. Normal cari listen yalnız sana atanmış kayıtları içerir.',
                  ),
                  if (_hata != null) DurumNotu(_hata!, hata: true),
                  if (s.data!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Henüz cari yok.'),
                    ),
                  for (final o in s.data!)
                    ListTile(
                      title: Text(o.cari.ad),
                      subtitle: Text(
                        '${o.cari.kimlikNo.isEmpty ? 'VKN / TC eklenmemiş' : o.cari.kimlikNo} · ${widget.kullanicilar.where((k) => k.id == o.cari.sahipId).map((k) => k.ad).firstOrNull ?? 'Kullanıcı bulunamadı'}',
                      ),
                      trailing: const Icon(Icons.swap_horiz),
                      onTap: _mesgul ? null : () => _ata(o.cari),
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
