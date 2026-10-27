import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import '../domain/surum.dart';
import 'ortak.dart';
import 'tema.dart';

/// En düşük sürümün altındaki uygulama (Android): yalnız indirme ve çıkış.
/// Telefondaki kartlar ve kaydedilmeyi bekleyen DenizPay sonuçları silinmez;
/// yeni sürüm aynı uygulamanın üstüne kurulur ve onları kullanır.
class GuncellemeSayfasi extends StatelessWidget {
  const GuncellemeSayfasi({
    super.key,
    required this.bilgi,
    required this.cikis,
  });
  final AndroidSurumu bilgi;
  final Future<void> Function() cikis;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: SinirliIcerik(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.system_update_rounded,
                size: 56,
                color: PosRenk.vurgu,
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: const Text(
                  'Güncelleme gerekli',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu sürüm artık kullanılamıyor. Devam etmek için '
                '${bilgi.sonAd} sürümünü indirip kur.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 20),
              const DurumNotu(
                'Kartların ve kaydedilmeyi bekleyen ödeme sonuçların bu '
                'telefonda kalır; yeni sürüm kurulunca kaldığı yerden devam eder. '
                'Uygulamayı kaldırma, yalnız yeni sürümü üstüne kur.',
              ),
              const SizedBox(height: 24),
              IndirmeDugmesi(bilgi: bilgi, dolu: true),
              const SizedBox(height: 10),
              TextButton(onPressed: cikis, child: const Text('Çıkış yap')),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ana ekranda yeni sürüm notu; kapatılınca bu açılışta yeniden çıkmaz.
class GuncellemeNotu extends StatelessWidget {
  const GuncellemeNotu({super.key, required this.bilgi, required this.kapat});
  final AndroidSurumu bilgi;
  final VoidCallback kapat;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
    decoration: BoxDecoration(
      color: PosRenk.acikVurgu,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.system_update_rounded, color: PosRenk.vurgu, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Yeni sürüm hazır: ${bilgi.sonAd}',
            style: const TextStyle(fontSize: 13, color: PosRenk.koyu),
          ),
        ),
        IndirmeDugmesi(bilgi: bilgi),
        IconButton(
          tooltip: 'Notu kapat',
          onPressed: kapat,
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    ),
  );
}

/// Kurulum sayfası telefonun tarayıcısında açılır (uygulama içinde değil):
/// APK indirme ve kurulum izni tarayıcı üzerinden yürür.
class IndirmeDugmesi extends StatelessWidget {
  const IndirmeDugmesi({super.key, required this.bilgi, this.dolu = false});
  final AndroidSurumu bilgi;
  final bool dolu;
  @override
  Widget build(BuildContext context) => Link(
    uri: bilgi.indirme,
    target: LinkTarget.blank,
    builder: (context, ac) => dolu
        ? FilledButton.icon(
            onPressed: ac,
            icon: const Icon(Icons.download_rounded),
            label: Text('${bilgi.sonAd} sürümünü indir'),
          )
        : TextButton(onPressed: ac, child: const Text('İndir')),
  );
}
