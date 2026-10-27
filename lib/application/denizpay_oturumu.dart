import 'dart:async';
import '../domain/denizpay.dart';
import '../domain/hata.dart';
import '../domain/kart_bilgileri.dart';
import '../domain/modeller.dart';
import '../domain/pos_girisi.dart';
import '../domain/tahsilat.dart';

/// Uygulama içi DenizPay ekranının tarayıcısı (Android WebView bağdaştırıcısı).
/// Sayfa betikleri yalnız DenizPay kökeninde çalışır; banka sayfalarına
/// dokunulmaz. Kart, şifre veya sayfa içeriği günlüğe yazılmaz.
abstract interface class DenizPayTarayicisi {
  /// Önceki oturumun çerez, önbellek ve yerel depolamasını siler.
  Future<void> temizle();

  /// Sabit giriş adresine form POST'u (alanlar `web/pos_giris.js` ile aynı).
  Future<void> girisYap(Uri adres, PosGirisBilgisi giris);

  /// Açık sayfa DenizPay ise sayfa özeti (JSON nesnesi), değilse `null`.
  Future<Object?> ozetAl();

  /// Kart sayfasına numara, ad, son kullanma yazar. Sonuç kodu: `tamam`,
  /// `firma` (sayfadaki firma numarası farklı), `kutu` (kutular bulunamadı),
  /// `eksik` (numara kutuya tam yazılamadı), `sayfa` (DenizPay sayfası değil).
  Future<String> kartiYaz({
    required String numara,
    required String sahibi,
    required int ay,
    required int yil,
    required String kimlikNo,
  });
}

/// Sonucu bu cihazın bekleyen sonuç kutusuna bırakır; kutuyu işleyen servis
/// ([TahsilatServisi.kutuyuIsle]) sunucuya yazar ve [yanitlar] ile bildirir.
abstract interface class SonucBirakmaPortu {
  /// `ok` veya `zaten` (aynı kimlikte sonuç kutuda bekliyor).
  Future<String> birak(Map<String, Object?> kayit);
  Stream<({String kimlik, bool tamam, String mesaj})> get yanitlar;
}

/// Ekranın açıldığı seçim: doğrulanmış giriş bilgisi, sunucu giriş kaydı
/// (cari, giriş kimliği) ve isteğe bağlı kart özeti (kart seçmeden de girilir).
class DenizPayBaglami {
  const DenizPayBaglami({required this.giris, required this.kayit, this.kart});
  final PosGirisBilgisi giris;
  final PosGirisi kayit;
  final KartOzeti? kart;
}

enum DenizPaySayfasi { yukleniyor, denizPay, kart, sonuc, disSite }

class DenizPayDurumu {
  const DenizPayDurumu({
    this.adres,
    this.sayfa = DenizPaySayfasi.yukleniyor,
    this.firmaUyumsuz = false,
    this.sonuc,
    this.sonucHatasi,
    this.not,
    this.notHata = false,
    this.mesgul = false,
    this.kayitNotu,
    this.kayitTamam = false,
    this.kayitHata = false,
    this.birakildi = false,
  });
  final Uri? adres;
  final DenizPaySayfasi sayfa;

  /// Açık DenizPay sayfasındaki firma numarası seçili cari değil.
  final bool firmaUyumsuz;
  final OkunanSonuc? sonuc;

  /// Sonuç ekranı ama okunamadı: kişi elle kaydeder.
  final String? sonucHatasi;
  final String? not;
  final bool notHata, mesgul;

  /// Kaydın sunucu yanıtı (kaydedildi / bekliyor / farklı).
  final String? kayitNotu;
  final bool kayitTamam, kayitHata, birakildi;

  DenizPayDurumu kopya({
    Uri? adres,
    DenizPaySayfasi? sayfa,
    bool? firmaUyumsuz,
    OkunanSonuc? Function()? sonuc,
    String? Function()? sonucHatasi,
    String? Function()? not,
    bool? notHata,
    bool? mesgul,
    String? Function()? kayitNotu,
    bool? kayitTamam,
    bool? kayitHata,
    bool? birakildi,
  }) => DenizPayDurumu(
    adres: adres ?? this.adres,
    sayfa: sayfa ?? this.sayfa,
    firmaUyumsuz: firmaUyumsuz ?? this.firmaUyumsuz,
    sonuc: sonuc != null ? sonuc() : this.sonuc,
    sonucHatasi: sonucHatasi != null ? sonucHatasi() : this.sonucHatasi,
    not: not != null ? not() : this.not,
    notHata: notHata ?? this.notHata,
    mesgul: mesgul ?? this.mesgul,
    kayitNotu: kayitNotu != null ? kayitNotu() : this.kayitNotu,
    kayitTamam: kayitTamam ?? this.kayitTamam,
    kayitHata: kayitHata ?? this.kayitHata,
    birakildi: birakildi ?? this.birakildi,
  );
}

/// Bir cari için açılan uygulama içi DenizPay oturumu. Oturum her açılışta
/// temizlenir: açılan DenizPay hesabı yalnız bu carinindir. Kart yalnız kişi
/// "Kartı doldur"a basınca, sayfadaki firma numarası carininkiyle aynıysa ve
/// kart sunucuda yeniden doğrulanınca yazılır. CVV, tutar ve ödeme düğmesine
/// dokunulmaz. Sonuç yalnız kişi onaylayınca bu cariye kaydedilir.
class DenizPayOturumu {
  DenizPayOturumu({
    required this.baglam,
    required this.tarayici,
    required this.adres,
    required this.birakma,
    required this.kartiOku,
    DateTime Function()? saat,
  }) : saat = saat ?? DateTime.now {
    _yanit = birakma.yanitlar.listen(_yanitGeldi);
  }
  final DenizPayBaglami baglam;
  final DenizPayTarayicisi tarayici;
  final DenizPayAdresi adres;
  final SonucBirakmaPortu birakma;

  /// Kartın tam bilgisi: sunucuda güncel kart referansı doğrulandıktan sonra
  /// cihaz kasasından (`PosServisi.kartBilgileri`).
  final Future<KartBilgileri?> Function() kartiOku;
  final DateTime Function() saat;

  final _durumlar = StreamController<DenizPayDurumu>.broadcast();
  late final StreamSubscription<void> _yanit;
  DenizPayDurumu _durum = const DenizPayDurumu();
  int _sayfaNesli = 0;
  bool _kapali = false;

  DenizPayDurumu get durum => _durum;
  Stream<DenizPayDurumu> get durumlar => _durumlar.stream;

  bool get kartDoldurulabilir =>
      baglam.kart?.cihazKayitId != null &&
      _durum.sayfa == DenizPaySayfasi.kart &&
      !_durum.firmaUyumsuz &&
      !_durum.mesgul;

  void _yay(DenizPayDurumu d) {
    if (_kapali) return;
    _durum = d;
    _durumlar.add(d);
  }

  /// Önceki DenizPay oturumu silinir, sonra bu carinin bilgileriyle girilir.
  Future<void> baslat() async {
    await tarayici.temizle();
    await tarayici.girisYap(adres.giris, baglam.giris);
  }

  /// WebView'in gezinme isteği için karar (bağdaştırıcı sorar).
  Gezinme gezinme(Uri u) => adres.karar(u);

  /// Sayfa yüklendi. Eşzamanlı yüklemelerde yalnız son sayfanın sonucu geçer.
  Future<void> sayfaYuklendi(Uri u) async {
    final nesil = ++_sayfaNesli;
    final temel = _durum.kopya(
      adres: u,
      firmaUyumsuz: false,
      sonuc: () => null,
      sonucHatasi: () => null,
      not: () => null,
      notHata: false,
    );
    if (adres.karar(u) != Gezinme.denizPay) {
      _yay(temel.kopya(sayfa: DenizPaySayfasi.disSite));
      return;
    }
    SayfaOzeti? ozet;
    try {
      ozet = SayfaOzeti.oku(await tarayici.ozetAl());
    } catch (_) {
      ozet = null;
    }
    if (nesil != _sayfaNesli) return;
    if (ozet == null) {
      _yay(temel.kopya(sayfa: DenizPaySayfasi.denizPay));
      return;
    }
    final uyumsuz = ozet.firma != null && ozet.firma != baglam.giris.vergiNo;
    if (ozet.kartAlanlari) {
      // Kart yalnız firma numarası görünen ve carininkiyle aynı sayfaya yazılır.
      _yay(
        temel.kopya(
          sayfa: DenizPaySayfasi.kart,
          firmaUyumsuz: uyumsuz || ozet.firma == null,
          not: () => uyumsuz
              ? 'Bu DenizPay sayfası seçili cariye ait değil. Kart yazılmaz; ekranı kapatıp doğru cariyle yeniden gir.'
              : ozet!.firma == null
              ? 'Sayfada firma numarası bulunamadı; güvenlik için kart yazılmaz. Kart bilgilerini elle yazabilirsin.'
              : null,
          notHata: uyumsuz || ozet.firma == null,
        ),
      );
      return;
    }
    final r = sonucCoz(ozet);
    final metin = ozet.metin.toLowerCase();
    final sonucEkrani =
        r.sonuc != null ||
        metin.contains('onay formu') ||
        metin.contains('hata formu');
    if (!sonucEkrani) {
      _yay(temel.kopya(sayfa: DenizPaySayfasi.denizPay, firmaUyumsuz: uyumsuz));
      return;
    }
    _yay(
      temel.kopya(
        sayfa: DenizPaySayfasi.sonuc,
        firmaUyumsuz: uyumsuz,
        sonuc: () => uyumsuz ? null : r.sonuc,
        sonucHatasi: () => uyumsuz
            ? 'Bu sonuç ekranı seçili cariye ait değil; kaydedilmedi. DenizPay’de kontrol edip yöneticine bildir.'
            : r.hata,
        birakildi: false,
        kayitNotu: () => null,
        kayitTamam: false,
        kayitHata: false,
      ),
    );
  }

  /// "Kartı doldur": kart sunucuda doğrulanıp kasadan çözülür, yalnız açık
  /// DenizPay kart sayfasına ve yalnız firma numarası tutarsa yazılır.
  Future<void> kartiDoldur() async {
    final kart = baglam.kart;
    if (!kartDoldurulabilir || kart == null) return;
    _yay(_durum.kopya(mesgul: true, not: () => null, notHata: false));
    String mesaj;
    var hata = true;
    try {
      final b = await kartiOku();
      if (b == null) {
        mesaj =
            'Bu kartın tam bilgisi bu telefonda yok. Kartı bu telefonda ekle ya da bilgileri elle yaz.';
      } else {
        final r = await tarayici.kartiYaz(
          numara: b.numara,
          sahibi: b.sahibi,
          ay: kart.ay,
          yil: kart.yil,
          kimlikNo: baglam.giris.vergiNo,
        );
        (mesaj, hata) = switch (r) {
          'tamam' => (
            'Kart yazıldı (•••• ${kart.sonDort}). Şimdi CVV ve tutarı yaz, ödemeyi sen onayla.',
            false,
          ),
          'firma' => (
            'Bu DenizPay sayfası seçili cariye ait değil. Kart yazılmadı.',
            true,
          ),
          'eksik' => (
            'Kart numarası kutuya tam yazılamadı; kontrol et veya elle yaz.',
            true,
          ),
          _ => ('Kart kutuları bulunamadı. Kart bilgilerini elle yaz.', true),
        };
      }
    } on PosHatasi catch (e) {
      mesaj = e.mesaj;
    } catch (_) {
      mesaj = 'Kart yazılamadı. Bilgileri elle yaz.';
    }
    _yay(_durum.kopya(mesgul: false, not: () => mesaj, notHata: hata));
  }

  /// "Bu cariye kaydet": sonuç bu cihazın bekleyen kutusuna bırakılır; kutuyu
  /// işleyen servis sunucuya yazar, internet yoksa sonra yeniden dener.
  Future<void> sonucuKaydet() async {
    final s = _durum.sonuc;
    if (s == null || _durum.birakildi || _durum.mesgul) return;
    _yay(_durum.kopya(mesgul: true));
    final k = baglam.kayit;
    final kayit = <String, Object?>{
      'v': 3,
      'eslesme': CariEslesmesi.uygulamaIci.kod,
      'uid': k.kullaniciId,
      'girisId': k.id,
      'cariId': k.cariId,
      'cariAd': k.cariAd,
      'kimlikNo': k.kimlikNo,
      'kartSonDort': k.kartSonDort,
      'sonuc': s.sonuc == IslemSonucu.basarili ? 'basarili' : 'hata',
      'aciklama': s.aciklama,
      'posSiparisNo': s.posSiparisNo,
      'uyeSiparisNo': s.uyeSiparisNo,
      'tutarMetni': s.tutarMetni,
      'okunma': saat().millisecondsSinceEpoch,
    };
    try {
      final r = await birakma.birak(kayit);
      _yay(
        _durum.kopya(
          mesgul: false,
          birakildi: true,
          kayitNotu: () =>
              r == 'zaten' ? 'Bu sonuç zaten kaydediliyor.' : 'Kaydediliyor…',
        ),
      );
    } catch (_) {
      _yay(
        _durum.kopya(
          mesgul: false,
          kayitNotu: () =>
              'Sonuç telefonda saklanamadı. Cari profilinden “Ödeme sonucunu elle kaydet” ile kaydet.',
          kayitTamam: false,
          kayitHata: true,
        ),
      );
    }
  }

  void _yanitGeldi(({String kimlik, bool tamam, String mesaj}) y) {
    final s = _durum.sonuc;
    if (s == null || y.kimlik != belgeKimligi(s.posSiparisNo, s.sonuc)) return;
    _yay(
      _durum.kopya(
        kayitNotu: () => y.mesaj,
        kayitTamam: y.tamam,
        kayitHata: !y.tamam,
      ),
    );
  }

  /// Ekran kapanınca (elle, kilit, çıkış): DenizPay oturumu hemen silinir;
  /// dinleyicilerin kapanması beklenmez (silme hiçbir koşulda gecikmesin).
  Future<void> kapat() async {
    if (_kapali) return;
    _kapali = true;
    unawaited(_yanit.cancel());
    unawaited(_durumlar.close());
    try {
      await tarayici.temizle();
    } catch (_) {}
  }
}
