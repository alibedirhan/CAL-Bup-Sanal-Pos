import 'package:flutter/material.dart';
import '../domain/gun_sonu.dart';
import '../domain/tahsilat.dart';
import 'tema.dart';

/// "Gün devam ediyor" / "Gün kapandı" etiketi.
class GunDurumu extends StatelessWidget {
  const GunDurumu({super.key, required this.kapandi});
  final bool kapandi;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          kapandi ? Icons.lock_clock_outlined : Icons.schedule_rounded,
          size: 18,
          color: kapandi ? PosRenk.vurgu : PosRenk.ikincil,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            kapandi
                ? 'Gün kapandı · gün sonu kesin'
                : 'Gün devam ediyor · 24:00’te kendiliğinden kapanır',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: PosRenk.ikincil),
          ),
        ),
      ],
    ),
  );
}

/// Günün başarılı tahsilat toplamı ve işlem sayıları.
class GunToplami extends StatelessWidget {
  const GunToplami({super.key, required this.gunSonu});
  final GunSonu gunSonu;
  @override
  Widget build(BuildContext context) {
    final g = gunSonu;
    return Semantics(
      container: true,
      label:
          'Gün toplamı ${tutarYaz(g.toplamKurus)}, ${g.basariliAdet} başarılı, ${g.hataAdet} başarısız işlem',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PosRenk.koyu,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Başarılı tahsilat',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                tutarYaz(g.toplamKurus),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${g.cariler.length} cari · ${g.basariliAdet} başarılı · '
              '${g.hataAdet} başarısız',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir carinin günlük işlemleri: toplam ve saat sırasıyla her deneme.
class CariGunKarti extends StatelessWidget {
  const CariGunKarti({
    super.key,
    required this.ozet,
    this.kullaniciGoster = false,
  });
  final CariGunOzeti ozet;
  final bool kullaniciGoster;
  @override
  Widget build(BuildContext context) {
    final c = ozet;
    // Her cari ekran okuyucuda ayrı bölüm; işlem satırları ayrı okunur.
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: PosRenk.beyaz,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PosRenk.cizgi),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.cariAd,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'VKN / TC ${c.kimlikNo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: PosRenk.ikincil,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  tutarYaz(c.toplamKurus),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: PosRenk.koyu,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (c.islemler.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'DenizPay’e girildi; sonuç kaydı yok.',
                  style: TextStyle(fontSize: 13, color: PosRenk.uyari),
                ),
              ),
            for (final i in c.islemler)
              _IslemSatiri(islem: i, kullaniciGoster: kullaniciGoster),
          ],
        ),
      ),
    );
  }
}

class _IslemSatiri extends StatelessWidget {
  const _IslemSatiri({required this.islem, required this.kullaniciGoster});
  final PosIslemi islem;
  final bool kullaniciGoster;
  @override
  Widget build(BuildContext context) {
    final i = islem;
    final tutar = i.tutarKurus == null
        ? '${i.tutarMetni} (okunamadı)'
        : tutarYaz(i.tutarKurus!);
    final ayrinti = [
      'Pos No ${i.posSiparisNo}',
      if (i.kartSonDort.isNotEmpty) '•••• ${i.kartSonDort}',
      if (i.kaynak == IslemKaynagi.elle) 'elle kaydedildi',
      if (i.eslesme == CariEslesmesi.secim) 'cari seçilerek kaydedildi',
      if (kullaniciGoster) i.kullaniciAd,
    ].join(' · ');
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              i.basarili ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20,
              color: i.basarili ? PosRenk.vurgu : PosRenk.hata,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${saatYaz(i.zaman!)} · $tutar'
                    '${i.basarili ? '' : ' · Başarısız'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i.basarili ? PosRenk.metin : PosRenk.hata,
                    ),
                  ),
                  if (!i.basarili)
                    Text(i.aciklama, style: const TextStyle(fontSize: 13)),
                  if (i.gecOkunma case final o?)
                    Text(
                      'DenizPay sonucu ${tarihSaatYaz(o)}’de okundu',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosRenk.uyari,
                      ),
                    ),
                  Text(
                    ayrinti,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PosRenk.ikincil,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
