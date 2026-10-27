import 'package:flutter/material.dart';
import 'cari_formu.dart';
import 'pos_giris_bilgileri.dart';
import 'kart_kutusu.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';
import 'tema.dart';
import '../application/hesap_portu.dart';
import 'cari_atama.dart';
import 'kart_formu.dart';
import 'kart_silme.dart';
import 'islem_formu.dart';

class CariProfiliEkrani extends StatelessWidget {
  const CariProfiliEkrani({super.key, required this.model, this.yonetim});
  final OturumModeli model;
  final YonetimPortu? yonetim;
  Future<void> _sil(BuildContext context) async {
    final p = model.profil!;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari silinsin mi?'),
        content: Text(
          '${p.cari.ad} ve bağlı ${p.kartlar.length} kart özeti ${model.deneme ? 'bu deneme oturumundan silinecek' : 'aktif kayıtlardan kaldırılacak'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cariyi sil'),
          ),
        ],
      ),
    );
    if (onay == true && context.mounted) await model.cariSil(p.cari);
  }

  @override
  Widget build(BuildContext context) {
    final p = model.profil!;
    // Sıra kullanım sıklığına göre: kart seçimi en üstte (küçük ekranda da
    // ilk bakışta görünsün), seyrek kullanılan cari işlemleri en altta.
    return ListView(
      children: [
        SinirliIcerik(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CariAvatar(p.cari.ad),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.cari.ad,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.cari.kimlikNo.isEmpty
                              ? 'VKN / TC eklenmemiş'
                              : 'VKN / TC ${p.cari.kimlikNo}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: p.cari.yildizli ? 'Yıldızı kaldır' : 'Yıldızla',
                    onPressed: model.mesgul
                        ? null
                        : () => model.yildizla(p.cari),
                    icon: Icon(
                      p.cari.yildizli
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: p.cari.yildizli ? PosRenk.uyari : PosRenk.ikincil,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Kayıtlı kartlar (${p.kartlar.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('İşlem için bir kart seç.'),
              const SizedBox(height: 14),
              if (model.hata != null) ...[
                DurumNotu(model.hata!, hata: true),
                const SizedBox(height: 16),
              ],
              if (p.kartlar.isEmpty)
                const BosDurum(
                  simge: Icons.credit_card_off_outlined,
                  baslik: 'Henüz kart yok',
                  aciklama:
                      '“Kart ekle” ile bu cariye ait kartı kaydedebilirsin.',
                ),
              for (final kart in p.kartlar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      KartKutusu(
                        kart: kart,
                        secili: model.seciliKartId == kart.id,
                        gecmis: kart.suresiGecti(model.servis.saat()),
                        onSec: model.mesgul ? null : () => model.kartSec(kart),
                      ),
                      if (!model.deneme)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: model.mesgul
                                  ? null
                                  : () => kartFormunuAc(
                                      context,
                                      model,
                                      kart: kart,
                                    ),
                              child: const Text('Bilgiler / düzenle'),
                            ),
                            IconButton(
                              tooltip: 'Kartı sil',
                              onPressed: model.mesgul
                                  ? null
                                  : () => kartSilmeOnayi(context, model, kart),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: model.mesgul || p.kartlar.length >= 10
                      ? null
                      : model.deneme
                      ? model.kartEkle
                      : () => kartFormunuAc(context, model),
                  icon: const Icon(Icons.add_card_outlined, size: 20),
                  label: Text(model.deneme ? 'Deneme kartı ekle' : 'Kart ekle'),
                ),
              ),
              if (p.kartlar.length >= 10)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Bu cariye en fazla 10 kart eklenebilir.'),
                ),
              if (model.servis.tahsilat != null &&
                  p.cari.kimlikNo.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: model.mesgul
                        ? null
                        : () => islemFormunuAc(
                            context,
                            model.servis.tahsilat!,
                            p,
                          ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    label: const Text('Ödeme sonucunu elle kaydet'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                'Cari bilgileri',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (p.cari.kimlikNo.isNotEmpty) ...[
                PosGirisBilgileri(kimlikNo: p.cari.kimlikNo),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: model.mesgul
                        ? null
                        : () => cariFormunuAc(context, model, cari: p.cari),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Düzenle'),
                  ),
                  if (yonetim != null)
                    OutlinedButton.icon(
                      onPressed: model.mesgul
                          ? null
                          : () => cariAta(context, model, yonetim!),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Kullanıcıya ata'),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: PosRenk.hata),
                    onPressed: model.mesgul ? null : () => _sil(context),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Cariyi sil'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              DurumNotu(
                model.deneme
                    ? 'Burada yalnız örnek kartların son dört hanesi bulunur. Gerçek kart bilgisi girilmez.'
                    : androidUygulamasi
                    ? 'Tam kart bilgileri yalnız eklendiği telefonda saklanır. Diğer cihazlarda maskeli özet görünür. CVV ödeme sitesinde girilir.'
                    : 'Tam kart bilgileri yalnız eklendiği tarayıcıda saklanır. Diğer cihazlarda maskeli özet görünür. CVV ödeme sitesinde girilir.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
