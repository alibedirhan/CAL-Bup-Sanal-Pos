import 'package:flutter/material.dart';
import 'ortak.dart';
import 'tema.dart';

class Karsilama extends StatelessWidget {
  const Karsilama({
    super.key,
    required this.devam,
    this.kilitli = false,
    this.canliKapali = false,
  });
  final VoidCallback devam;
  final bool kilitli, canliKapali;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: SinirliIcerik(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: PosRenk.koyu,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      kilitli
                          ? Icons.lock_outline_rounded
                          : Icons.credit_card_rounded,
                      size: 36,
                      color: PosRenk.beyaz,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'BUP  /  SANAL POS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: PosRenk.vurgu,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  canliKapali
                      ? 'Kurulum\nbekleniyor.'
                      : kilitli
                      ? 'Ekranın\nkilitlendi.'
                      : 'POS işlemlerin\nelinin altında.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  canliKapali
                      ? 'Gerçek hesap ve POS sağlayıcı bağlantısı tamamlanmadan canlı kullanım açılamaz.'
                      : kilitli
                      ? 'Deneme ekranı gizlendi. Devam ettiğinde cari ve kartını yeniden seçebilirsin.'
                      : 'Cariyi bul. Kartını seç.\nİşlemine kolayca hazırlan.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (!canliKapali)
                  FilledButton.icon(
                    onPressed: devam,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(kilitli ? 'Denemeye devam et' : 'Denemeyi aç'),
                  ),
                const SizedBox(height: 18),
                Text(
                  canliKapali
                      ? 'Bu paket deneme ekranına otomatik geçmez.'
                      : 'Yapay kayıtlarla çalışan önizleme. Gerçek kart, hesap girişi veya ödeme içermez.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: PosRenk.ikincil,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
