import '../domain/hata.dart';
import '../domain/modeller.dart';
import 'portlar.dart';
import 'kart_kasasi.dart';
import 'kart_islemleri.dart';
import '../domain/kart_bilgileri.dart';

/// Flutter, Firebase, tarayıcı ve ekran durumundan bağımsız iş akışı.
class PosServisi {
  PosServisi({
    required this.depo,
    required this.baglanti,
    required this.kullaniciId,
    DateTime Function()? saat,
    this.kartKasasi = const KapaliKartKasasi(),
  }) : saat = saat ?? DateTime.now;
  final KartKasasi kartKasasi;
  KartIslemleri get _kart => KartIslemleri(depo, kartKasasi, kullaniciId);
  final CariDeposu depo;
  final PosBaglantisi baglanti;
  final String kullaniciId;
  final DateTime Function() saat;
  bool _aktarimSuruyor = false;

  Future<List<CariOzeti>> listele() => depo.listele(kullaniciId);
  Future<CariProfili> profil(String id) => depo.profil(kullaniciId, id);
  Future<Cari> ekle(String ad, String kod, {String kimlikNo = ''}) =>
      depo.ekle(kullaniciId, ad, kod, kimlikNo: kimlikNo);
  Future<void> kaydet(Cari yeni, int beklenen) =>
      depo.kaydet(kullaniciId, yeni, beklenen);
  Future<String?> sil(Cari cari) async {
    await depo.sil(kullaniciId, cari.id, cari.surum);
    return _kart.temizle(cari.id, null);
  }

  Future<void> denemeKartiEkle(String cariId) =>
      depo.denemeKartiEkle(kullaniciId, cariId);
  Future<KartKayitSonucu> kartKaydet(
    Cari cari,
    KartOzeti kart, {
    KartBilgileri? bilgiler,
  }) => _kart.kaydet(cari, kart, bilgiler, saat());
  Future<KartBilgileri?> kartBilgileri(
    KartOzeti kart,
    bool Function() oturumAcik,
  ) => _kart.oku(kart, oturumAcik);
  Future<String?> kartSil(Cari cari, String kartId) async {
    await depo.kartSil(kullaniciId, cari.id, cari.surum, kartId);
    return _kart.temizle(cari.id, kartId);
  }

  Future<DenemeSonucu> dene(
    PosSecimi secim, {
    required bool Function() oturumAcik,
  }) async {
    if (_aktarimSuruyor) {
      throw const PosHatasi('mesgul', 'Geçiş hazırlanıyor. Lütfen bekleyin.');
    }
    _aktarimSuruyor = true;
    try {
      if (!oturumAcik()) {
        throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden kart seçin.');
      }
      // Ekrandaki eski nesneyle işlem yapılmaz: sahiplik ve güncel sürüm tekrar okunur.
      final guncel = await profil(secim.cariId);
      if (!oturumAcik()) {
        throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden kart seçin.');
      }
      if (guncel.cari.surum != secim.cariSurumu) {
        throw const PosHatasi(
          'surum',
          'Cari bilgisi değişti. Güncel kaydı yeniden seçin.',
        );
      }
      final kartlar = guncel.kartlar.where(
        (k) => k.id == secim.kartId && k.cariId == guncel.cari.id,
      );
      if (kartlar.length != 1) {
        throw const PosHatasi(
          'kart_yok',
          'Kart bulunamadı. Yeniden seçim yapın.',
        );
      }
      final kart = kartlar.single;
      if (kart.suresiGecti(saat())) {
        throw const PosHatasi(
          'gecmis',
          'Bu kartın süresi dolmuş. Başka bir kart seçin.',
        );
      }
      final sonuc = await baglanti.dene(guncel.cari, kart);
      if (!oturumAcik()) {
        throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden kart seçin.');
      }
      return sonuc;
    } finally {
      _aktarimSuruyor = false;
    }
  }
}
