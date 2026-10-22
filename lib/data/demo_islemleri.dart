import '../application/tahsilat_servisi.dart';
import '../domain/hata.dart';
import '../domain/tahsilat.dart';
import 'demo_deposu.dart';

/// Yalnız bellekte, yapay giriş/işlem kayıtları. Yenilemede sıfırlanır.
/// Canlı depo gibi yalnız ekler ve zamanı kendisi verir.
class DemoIslemDeposu implements IslemDeposu {
  DemoIslemDeposu({DateTime Function()? saat}) : _saat = saat ?? DateTime.now {
    final simdi = _saat();
    final gun = Gun.ani(simdi);
    // Bugün iki cari için örnek işlemler; zamanlar şu andan önce kalır.
    final ilk = simdi.isAfter(gun.baslangic.add(const Duration(minutes: 30)))
        ? gun.baslangic.add(
            Duration(minutes: simdi.difference(gun.baslangic).inMinutes ~/ 3),
          )
        : gun.baslangic;
    DateTime an(int dakika) => ilk.add(Duration(minutes: dakika));
    PosIslemi islem(
      String no,
      int c,
      IslemSonucu s,
      String tutar,
      String a,
      int dakika,
    ) => PosIslemi(
      posSiparisNo: no,
      kullaniciId: DemoDeposu.kullanici,
      kullaniciAd: 'Deneme Kullanıcısı',
      cariId: 'demo-cari-$c',
      cariAd: _adlar[c],
      kimlikNo: (c + 1).toString().padLeft(10, '0'),
      sonuc: s,
      aciklama: a,
      tutarMetni: tutar,
      kaynak: IslemKaynagi.yerImi,
      kartSonDort: '00${(c + 1).toString().padLeft(2, '0')}',
      uyeSiparisNo: s == IslemSonucu.basarili ? '1000$c$dakika' : '',
      zaman: an(dakika),
    );
    _islemler.addAll([
      islem(
        'VP0000000000000001',
        0,
        IslemSonucu.hata,
        '4500',
        '3D Şifresi Yanlış.',
        0,
      ),
      islem(
        'VP0000000000000002',
        0,
        IslemSonucu.basarili,
        '4500',
        'Ödeme Başarıyla Gerçekleştirildi',
        2,
      ),
      islem(
        'VP0000000000000003',
        1,
        IslemSonucu.basarili,
        '12.750,50',
        'Ödeme Başarıyla Gerçekleştirildi',
        5,
      ),
    ]);
  }
  static const _adlar = ['Örnek Kuzey Market', 'Örnek Sahil Gıda'];
  final DateTime Function() _saat;
  final _girisler = <PosGirisi>[];
  final _islemler = <PosIslemi>[];

  @override
  Future<void> girisKaydet(PosGirisi g) async {
    _girisler.add(
      PosGirisi(
        id: g.id,
        kullaniciId: g.kullaniciId,
        kullaniciAd: g.kullaniciAd,
        cariId: g.cariId,
        cariAd: g.cariAd,
        kimlikNo: g.kimlikNo,
        kartSonDort: g.kartSonDort,
        zaman: _saat(),
      ),
    );
  }

  @override
  Future<IslemKaydi> islemKaydet(PosIslemi i) async {
    for (final m in _islemler) {
      if (m.posSiparisNo != i.posSiparisNo) continue;
      if (m.kullaniciId != i.kullaniciId) {
        throw const PosHatasi(
          'pos_no_baska',
          'Bu Pos Sipariş Numarası başka bir kullanıcı adına kayıtlı. Numarayı kontrol et.',
        );
      }
      return IslemKaydi(m, zatenVardi: true);
    }
    final yeni = PosIslemi(
      posSiparisNo: i.posSiparisNo,
      kullaniciId: i.kullaniciId,
      kullaniciAd: i.kullaniciAd,
      cariId: i.cariId,
      cariAd: i.cariAd,
      kimlikNo: i.kimlikNo,
      sonuc: i.sonuc,
      aciklama: i.aciklama,
      tutarMetni: i.tutarMetni,
      kaynak: i.kaynak,
      kartSonDort: i.kartSonDort,
      girisId: i.girisId,
      uyeSiparisNo: i.uyeSiparisNo,
      zaman: _saat(),
    );
    _islemler.add(yeni);
    return IslemKaydi(yeni, zatenVardi: false);
  }

  @override
  Future<GunKayitlari> gun(Gun gun, {String? kullaniciId}) async {
    bool uygun(String uid, DateTime? z) =>
        (kullaniciId == null || uid == kullaniciId) &&
        !z!.isBefore(gun.baslangic) &&
        z.isBefore(gun.bitis);
    return (
      girisler: [
        for (final g in _girisler)
          if (uygun(g.kullaniciId, g.zaman)) g,
      ],
      islemler: [
        for (final i in _islemler)
          if (uygun(i.kullaniciId, i.zaman)) i,
      ],
    );
  }
}
