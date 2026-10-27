import '../domain/doldurma.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import 'portlar.dart';
import 'kart_kasasi.dart';
import 'kart_islemleri.dart';
import '../domain/kart_bilgileri.dart';
import '../domain/pos_girisi.dart';
import '../domain/tahsilat.dart';
import 'denizpay_oturumu.dart';
import 'tahsilat_servisi.dart';

/// Flutter, Firebase, tarayıcı ve ekran durumundan bağımsız iş akışı.
class PosServisi {
  PosServisi({
    required this.depo,
    required this.baglanti,
    required this.kullaniciId,
    DateTime Function()? saat,
    this.kartKasasi = const KapaliKartKasasi(),
    this.girisKapisi = const KapaliPosGirisKapisi(),
    this.doldurma = const KapaliDoldurmaHazirligi(),
    this.tahsilat,
    this.uygulamaIciDenizPay = false,
  }) : saat = saat ?? DateTime.now;

  /// Android: DenizPay uygulamanın içinde açılır (docs/ANDROID_PLANI.md §3);
  /// giriş [uygulamaIciGirisHazirla] ile, ekran arayüzce açılır.
  final bool uygulamaIciDenizPay;

  /// Canlı kipte giriş/işlem kayıtları ve gün sonu; demoda bellekte.
  final TahsilatServisi? tahsilat;
  static const girisSuresi = Duration(minutes: 2);
  final PosGirisKapisi girisKapisi;
  final DoldurmaHazirligi doldurma;
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
      if (secim.kartId == null) {
        return DenemeSonucu(
          guncel.cari.ad,
          '',
          kimlikNo: guncel.cari.kimlikNo,
          zaman: saat(),
          cariId: guncel.cari.id,
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
      return DenemeSonucu(
        sonuc.cariAdi,
        sonuc.kartSonDort,
        kimlikNo: guncel.cari.kimlikNo,
        zaman: saat(),
        kart: kart,
        cariId: guncel.cari.id,
      );
    } finally {
      _aktarimSuruyor = false;
    }
  }

  bool get otomatikGiris => girisKapisi.destekli || uygulamaIciDenizPay;

  /// Seçim kontrolü kısa süre önce yapılmış olmalı; giriş bilgisi o an üretilir.
  PosGirisBilgisi _dogrulanmisGiris(DenemeSonucu sonuc) {
    final zaman = sonuc.zaman;
    final fark = zaman == null ? null : saat().difference(zaman);
    if (fark == null || fark.isNegative || fark > girisSuresi) {
      throw const PosHatasi(
        'sure',
        'Seçim kontrolünün süresi doldu. Kartlara dönüp yeniden kontrol et.',
      );
    }
    return PosGirisBilgisi.kimlikten(sonuc.kimlikNo);
  }

  /// Android uygulama içi DenizPay: doğrulanmış seçimden ekranın bağlamı. Giriş
  /// kaydı hazırlanır (sunucuya ayrıca [TahsilatServisi.girisKaydet] ile).
  /// Kart seçilmediyse de girilir; kart bilgileri o zaman elle yazılır.
  DenizPayBaglami uygulamaIciGirisHazirla(DenemeSonucu sonuc) {
    final t = tahsilat;
    if (!uygulamaIciDenizPay || t == null) {
      throw const PosHatasi(
        'giris_yok',
        'Uygulama içi DenizPay bu cihazda kullanılamıyor.',
      );
    }
    final giris = _dogrulanmisGiris(sonuc);
    return DenizPayBaglami(
      giris: giris,
      kayit: t.girisHazirla(sonuc),
      kart: sonuc.kart,
    );
  }

  /// Yalnız kısa süre önce doğrulanmış seçimle, eşzamanlı çağrılır. Dönen
  /// giriş kaydı (tahsilat açıksa) ayrıca sunucuya yazılmalıdır.
  PosGirisi? girisiAc(DenemeSonucu sonuc) {
    final giris = _dogrulanmisGiris(sonuc);
    // Kart sayfası yer imi için yalnız bu doğrulanmış kartın kasa referansı
    // bırakılır; kartsız veya başka cihazda eklenmiş kartta eski iş silinir.
    final kart = sonuc.kart;
    doldurmayiTemizle();
    if (kart != null && kart.cihazKayitId != null && doldurma.destekli) {
      doldurma.hazirla(
        DoldurmaIsi(
          kullaniciId: kullaniciId,
          kart: kart,
          kimlikNo: sonuc.kimlikNo,
          son: saat().add(DoldurmaIsi.sure),
        ),
      );
    }
    // Sonuç ekranındaki yer imi sonucu bu cariye bağlar; DenizPay'den önce yazılır.
    final kayit = tahsilat?.girisHazirla(sonuc);
    girisKapisi.ac(giris);
    return kayit;
  }

  /// Hata yutulur: temizleme kilit/çıkış akışını hiçbir zaman durdurmaz.
  void doldurmayiTemizle() {
    try {
      doldurma.temizle();
    } catch (_) {}
  }
}
