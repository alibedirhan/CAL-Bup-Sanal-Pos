import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/pos_girisi.dart';

class PosGirisBilgileri extends StatelessWidget {
  const PosGirisBilgileri({super.key, required this.kimlikNo});
  final String kimlikNo;

  Future<void> _kopyala(
    BuildContext context,
    String deger,
    String mesaj,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: deger));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mesaj)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kopyalanamadı. Tarayıcının pano iznini kontrol et.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Vergi / TC: $kimlikNo'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _kopyala(context, kimlikNo, 'Numara kopyalandı.'),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('VKN / TC kopyala'),
          ),
          OutlinedButton.icon(
            onPressed: () => _kopyala(
              context,
              posGirisSifresi(kimlikNo),
              'POS şifresi kopyalandı.',
            ),
            icon: const Icon(Icons.password_outlined, size: 18),
            label: const Text('POS şifresini kopyala'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Ödeme sitesi şifresi: numaranın ilk iki ve son iki hanesi.'),
    ],
  );
}
