import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import '../domain/kullanici.dart';
import 'oturum_modeli.dart';
import 'ortak.dart';

Future<void> cariAta(
  BuildContext context,
  OturumModeli model,
  YonetimPortu port,
) async {
  final cari = model.profil!.cari;
  try {
    final kullanicilar = (await port.kullanicilar())
        .where((k) => k.aktif && k.id != cari.sahipId)
        .toList();
    if (!context.mounted) return;
    final secim = await showDialog<Kullanici>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıya ata'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${cari.ad} seçtiğin kullanıcının listesine taşınacak.'),
                const SizedBox(height: 16),
                if (kullanicilar.isEmpty)
                  const Text(
                    'Atanabilecek başka aktif kullanıcı yok. Önce kullanıcı hesabı aç.',
                  ),
                for (final k in kullanicilar)
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
    if (secim == null || !context.mounted) return;
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
    if (onay != true) return;
    await port.ata(cari.id, cari.surum, secim.id);
    model.geri();
    await model.yukle();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cari atandı.')));
    }
  } catch (e) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: DurumNotu(
            e is PosHatasi ? e.mesaj : 'Atama tamamlanamadı.',
            hata: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }
  }
}
