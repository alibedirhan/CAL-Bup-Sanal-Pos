import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import 'ortak.dart';
import 'tema.dart';
import '../application/hesap_portu.dart';
import '../application/rota_kurulumu.dart';
import '../domain/kullanici.dart';
import 'konum_kurulumu.dart';
import 'parola_sayfasi.dart';
import 'yonetim_sayfasi.dart';

class BilgiSayfasi extends StatelessWidget {
  const BilgiSayfasi({
    super.key,
    required this.kilitle,
    this.kullanici,
    this.hesap,
    this.yonetim,
    this.rotaKurulumu,
  });
  final VoidCallback kilitle;
  final Kullanici? kullanici;
  final HesapPortu? hesap;
  final YonetimPortu? yonetim;

  /// Yalnız Android ve yönetici: terminalin konum kurulumu (rota). Göze
  /// çarpmayan bir düğmedir ve şifre yeniden sorulmadan açılmaz (M16).
  final RotaKurulumPortu? rotaKurulumu;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      SinirliIcerik(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Çalışma alanın',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            const Text('BUP Sanal POS · $surumAdi'),
            const SizedBox(height: 24),
            DurumNotu(
              kullanici == null
                  ? 'Deneme sürümü. Kayıtlar örnektir; sayfayı yenileyince başlangıca döner.'
                  : 'Yalnız sana atanmış cariler gösterilir. Kayıtlar hesabında saklanır; değişiklikler için internet bağlantısı gerekir.',
            ),
            const SizedBox(height: 24),
            _Bilgi(
              Icons.person_outline,
              kullanici?.ad ?? 'Deneme kullanıcısı',
              kullanici?.eposta ?? 'Gerçek hesap girişi henüz bağlı değil.',
            ),
            _Bilgi(
              Icons.credit_card_outlined,
              'Kart özetleri',
              androidUygulamasi
                  ? 'Kart bilgileri yalnız bu telefonda şifreli saklanır; diğer cihazlarda yalnız son dört hane görünür. CVV saklanmaz. Uygulamayı kaldırırsan kartları yeniden eklersin.'
                  : 'Tam kart bilgileri bu tarayıcıda şifreli tutulur. Diğer cihazlarda yalnız maskeli özet görünür. CVV kaydedilmez. Safari, Sanal POS’u uzun süre (yaklaşık 7 gün) hiç açmazsan bu bilgileri silebilir; o zaman kartı yeniden eklersin.',
            ),
            if (!androidUygulamasi)
              _Bilgi(
                Icons.sync_disabled,
                kullanici == null
                    ? 'Bu oturumda çalışır'
                    : 'Bağımsız kayıt alanı',
                kullanici == null
                    ? 'Buluta veya CAL bup’a kayıt gönderilmez.'
                    : 'Cariler ve kart özetleri bu uygulamanın ayrı kayıt alanındadır. CAL bup’a aktarım yapılmaz.',
              ),
            _Bilgi(
              Icons.open_in_new_rounded,
              'POS bağlantısı',
              kullanici == null
                  ? 'Şu an geçiş denemesi yapılabilir. Gerçek ödeme bağlantısı henüz kurulmadı.'
                  : androidUygulamasi
                  ? '“Ödeme sitesine geç” DenizPay’i bu uygulamanın içinde, seçili carinin VKN / TC ve POS şifresiyle açar; kart seçmeden de çalışır. Kart sayfasında “Kartı doldur”a bas. CVV ve tutarı her zaman sen yazarsın.'
                  : '“DenizPay’e giriş yap” seçili carinin VKN / TC ve POS şifresiyle DenizPay’i yeni sekmede açar; kart seçmeden de çalışır. Kart seçtiysen DenizPay kart sayfasında “BUP Doldur” yer imine dokun. CVV ve tutarı her zaman sen yazarsın.',
            ),
            if (hesap != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ParolaSayfasi(hesap: hesap!),
                  ),
                ),
                icon: const Icon(Icons.password),
                label: const Text('Şifremi değiştir'),
              ),
              const SizedBox(height: 12),
              if (yonetim != null)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => YonetimSayfasi(yonetim: yonetim!),
                    ),
                  ),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Kullanıcı yönetimi'),
                ),
              if (rotaKurulumu != null && kullanici?.yonetici == true) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () =>
                      konumKurulumunuAc(context, hesap!, rotaKurulumu!),
                  child: const Text('Yönetici kurulumu'),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: hesap!.cikis,
                child: const Text('Hesaptan çıkış yap'),
              ),
            ],
            // Yer imi yalnız tarayıcı sürümü içindir; Android'de "Kartı doldur" var.
            if (kullanici != null && !androidUygulamasi) ...[
              const SizedBox(height: 24),
              Text(
                'Kart doldurma yer imi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Telefona bir kez “BUP Doldur” yer imi kurulur. DenizPay kart sayfasında dokununca seçili kartın numarası, adı ve son kullanma tarihi yazılır; ödeme bitince sonuç ekranında dokununca sonuç doğru cariye kaydedilir. Kart sayfasında da dokunursan sonuç o DenizPay sekmesinin carisine kesin bağlanır; emin olunamazsa cariyi sen seçersin. 0.10.0’dan önce kurduysan bir kez yeniden kur.',
              ),
              const SizedBox(height: 12),
              Link(
                uri: Uri.base.resolve('kurulum.html'),
                target: LinkTarget.blank,
                builder: (context, ac) => OutlinedButton.icon(
                  onPressed: ac,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('BUP Doldur yer imini kur'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: kilitle,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Ekranı kilitle'),
            ),
            const SizedBox(height: 24),
            Text(
              'Telefonunda kolay erişim',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Yayınlandıktan sonra Android’de tarayıcı menüsünden, iPhone’da paylaş menüsünden “Ana Ekrana Ekle” seçeneğiyle açabilirsin.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ],
  );
}

class _Bilgi extends StatelessWidget {
  const _Bilgi(this.simge, this.baslik, this.aciklama);
  final IconData simge;
  final String baslik, aciklama;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(simge, color: PosRenk.vurgu),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(aciklama),
            ],
          ),
        ),
      ],
    ),
  );
}
