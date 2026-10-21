import 'package:flutter/foundation.dart';
import 'dart:async';
import '../application/portlar.dart';
import '../application/pos_servisi.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/kart_bilgileri.dart';

enum CariFiltresi { tumu, yildizli, kartli }

class OturumModeli extends ChangeNotifier {
  OturumModeli(this.servis, {this.deneme = true}) {
    final depo = servis.depo;
    if (!deneme && depo is CariIzlemePortu) {
      _izleme = (depo as CariIzlemePortu)
          .izle(servis.kullaniciId)
          .listen(
            (liste) {
              if (_kapali || kilitli || mesgul) return;
              final eski = profil?.cari;
              if (eski != null &&
                  !liste.any(
                    (c) => c.cari.id == eski.id && c.cari.surum == eski.surum,
                  )) {
                profil = null;
                seciliKartId = null;
              }
              cariler = liste;
              hazir = true;
              hata = null;
              notifyListeners();
            },
            onError: (Object e) {
              if (_kapali || kilitli) return;
              if (mesgul && e is PosHatasi && e.kod == 'baglanti') return;
              _nesil++;
              mesgul = false;
              cariler = const [];
              profil = null;
              seciliKartId = null;
              hata = e is PosHatasi
                  ? e.mesaj
                  : 'Erişim doğrulanamadı. Bağlantını kontrol et.';
              notifyListeners();
            },
          );
    }
  }
  StreamSubscription<List<CariOzeti>>? _izleme;
  final PosServisi servis;
  final bool deneme;
  List<CariOzeti> cariler = const [];
  CariProfili? profil;
  String? seciliKartId;
  String arama = '';
  CariFiltresi filtre = CariFiltresi.tumu;
  bool mesgul = false, kilitli = false, hazir = false;
  String? hata, uyari;
  String? hatayiAl() {
    final sonuc = hata;
    hata = null;
    notifyListeners();
    return sonuc;
  }

  int _nesil = 0;
  bool _kapali = false;

  List<CariOzeti> get gorunen => cariler
      .where(
        (c) =>
            c.cari.eslesir(arama) &&
            switch (filtre) {
              CariFiltresi.tumu => true,
              CariFiltresi.yildizli => c.cari.yildizli,
              CariFiltresi.kartli => c.kartSayisi > 0,
            },
      )
      .toList(growable: false);
  int get kartSayisi => cariler.fold(0, (toplam, c) => toplam + c.kartSayisi);
  KartOzeti? get seciliKart {
    for (final kart in profil?.kartlar ?? <KartOzeti>[]) {
      if (kart.id == seciliKartId) return kart;
    }
    return null;
  }

  void ara(String deger) {
    arama = deger;
    notifyListeners();
  }

  void suz(CariFiltresi deger) {
    filtre = deger;
    notifyListeners();
  }

  void geri() {
    profil = null;
    seciliKartId = null;
    hata = null;
    notifyListeners();
  }

  void kartSec(KartOzeti kart) {
    if (mesgul ||
        kilitli ||
        kart.cariId != profil?.cari.id ||
        kart.suresiGecti(servis.saat()) ||
        !profil!.kartlar.contains(kart)) {
      return;
    }
    seciliKartId = kart.id;
    hata = null;
    notifyListeners();
  }

  /// Sekme değişimi/boşta kilidi bekleyen kart işini silmez: DenizPay sekmesine
  /// geçmek akışın parçasıdır (iş zaten 10 dakikada biter). Elle kilit siler.
  void kilitle({bool bekleyenIsiSil = true}) {
    if (bekleyenIsiSil) servis.doldurmayiTemizle();
    if (kilitli) return;
    _nesil++;
    kilitli = true;
    mesgul = false;
    profil = null;
    seciliKartId = null;
    hata = null;
    arama = '';
    notifyListeners();
  }

  void denemeyeDon() {
    kilitli = false;
    notifyListeners();
  }

  Future<bool> _calistir(Future<void> Function(int nesil) islem) async {
    if (mesgul || kilitli || _kapali) return false;
    final nesil = _nesil;
    mesgul = true;
    hata = null;
    uyari = null;
    notifyListeners();
    try {
      await islem(nesil);
      return _guncel(nesil);
    } catch (e) {
      if (_guncel(nesil)) {
        hata = e is PosHatasi
            ? e.mesaj
            : 'İşlem tamamlanamadı. Lütfen yeniden deneyin.';
        if (e is PosHatasi && e.kod == 'yetki') {
          cariler = const [];
          profil = null;
          seciliKartId = null;
        }
      }
      return false;
    } finally {
      if (_guncel(nesil)) {
        mesgul = false;
        notifyListeners();
      }
    }
  }

  bool _guncel(int nesil) => !_kapali && !kilitli && nesil == _nesil;
  Future<void> _listele(int nesil) async {
    final sonuc = await servis.listele();
    if (_guncel(nesil)) {
      cariler = sonuc;
      hazir = true;
    }
  }

  Future<bool> yukle() => _calistir(_listele);
  Future<bool> profilAc(String id) => _calistir((nesil) async {
    final sonuc = await servis.profil(id);
    if (_guncel(nesil)) {
      profil = sonuc;
      seciliKartId = null;
    }
  });
  Future<bool> cariKaydet(
    String ad, {
    Cari? eski,
    required String kimlikNo,
  }) => _calistir((nesil) async {
    if (!RegExp(r'^[0-9]{10,11}$').hasMatch(kimlikNo)) {
      throw const PosHatasi('kimlik', '10 veya 11 rakam yaz.');
    }
    if (cariler.any(
      (o) => o.cari.id != eski?.id && o.cari.kimlikNo == kimlikNo,
    )) {
      throw const PosHatasi(
        'ayni_kimlik',
        'Bu vergi / TC numarası zaten kayıtlı. Mevcut cariyi aç.',
      );
    }
    final oncekiKartlar = profil?.cari.id == eski?.id
        ? profil?.kartlar ?? <KartOzeti>[]
        : <KartOzeti>[];
    final Cari yeni;
    if (eski == null) {
      // Eski kayıt şemasındaki kod alanı kullanıcıdan alınmaz. Yeni kayıtta
      // VKN/TC ile aynı atomik rezervasyonun kullanılması çift eklemeyi önler.
      yeni = await servis.ekle(ad, kimlikNo, kimlikNo: kimlikNo);
    } else {
      yeni = eski.duzenle(
        ad: ad,
        kimlikNo: kimlikNo,
        kod: kimlikNo == eski.kimlikNo ? eski.kod : kimlikNo,
      );
      await servis.kaydet(yeni, eski.surum);
    }
    if (!_guncel(nesil)) return;
    // İşlem sunucuda onaylandı. Başarıyı iki ek ağ okumasına bağlamayız:
    // okuma gecikirse kaydedilmiş cariyi başarısız gösterip tekrar ekletmeyiz.
    _profiliYerlestir(CariProfili(yeni, oncekiKartlar));
  });
  void _profiliYerlestir(CariProfili sonuc) {
    profil = sonuc;
    cariler = [
      for (final o in cariler)
        if (o.cari.id != sonuc.cari.id) o,
      CariOzeti(sonuc.cari, sonuc.kartlar.length),
    ];
    hazir = true;
    seciliKartId = null;
  }

  Future<bool> yildizla(Cari cari) => _calistir((nesil) async {
    final yeni = cari.duzenle(yildizli: !cari.yildizli);
    await servis.kaydet(yeni, cari.surum);
    if (!_guncel(nesil)) return;
    cariler = [
      for (final o in cariler)
        if (o.cari.id == yeni.id) CariOzeti(yeni, o.kartSayisi) else o,
    ];
    if (profil?.cari.id == cari.id) {
      profil = CariProfili(yeni, profil!.kartlar);
      seciliKartId = null;
    }
  });
  Future<bool> cariSil(Cari cari) => _calistir((nesil) async {
    final not = await servis.sil(cari);
    if (_guncel(nesil)) {
      uyari = not;
      cariler = cariler.where((o) => o.cari.id != cari.id).toList();
      profil = null;
      seciliKartId = null;
    }
  });
  Future<bool> kartEkle() => _calistir((nesil) async {
    final id = profil!.cari.id;
    await servis.denemeKartiEkle(id);
    await _listele(nesil);
    final p = await servis.profil(id);
    if (_guncel(nesil)) {
      profil = p;
      seciliKartId = null;
    }
  });
  Future<bool> kartKaydet(KartOzeti kart, {KartBilgileri? bilgiler}) =>
      _calistir((nesil) async {
        final p = profil!;
        final sonuc = await servis.kartKaydet(p.cari, kart, bilgiler: bilgiler);
        if (_guncel(nesil)) {
          uyari = sonuc.uyari;
          _profiliYerlestir(
            CariProfili(p.cari.duzenle(), [
              for (final k in p.kartlar)
                if (k.id != kart.id) k,
              sonuc.kart,
            ]),
          );
        }
      });
  Future<bool> kartSil(String kartId) => _calistir((nesil) async {
    final p = profil!;
    final not = await servis.kartSil(p.cari, kartId);
    if (_guncel(nesil)) {
      uyari = not;
      _profiliYerlestir(
        CariProfili(p.cari.duzenle(), p.kartlar.where((k) => k.id != kartId)),
      );
    }
  });
  Future<KartBilgileri?> kartBilgileri(KartOzeti kart) {
    final nesil = _nesil;
    return servis.kartBilgileri(
      kart,
      () =>
          _guncel(nesil) &&
          profil?.cari.id == kart.cariId &&
          profil!.kartlar.any(
            (k) => k.id == kart.id && k.cihazKayitId == kart.cihazKayitId,
          ),
    );
  }

  Future<DenemeSonucu?> dene() async {
    final p = profil;
    final kart = seciliKart;
    if (p == null || (kart == null && !otomatikGiris)) return null;
    DenemeSonucu? sonuc;
    final tamam = await _calistir((nesil) async {
      sonuc = await servis.dene(
        PosSecimi(
          cariId: p.cari.id,
          cariSurumu: p.cari.surum,
          kartId: kart?.id,
        ),
        oturumAcik: () => _guncel(nesil),
      );
    });
    return tamam ? sonuc : null;
  }

  /// Canlı kipte ve tarayıcı giriş formu yüklüyse "DenizPay'e giriş yap" görünür.
  bool get otomatikGiris => !deneme && servis.otomatikGiris;

  /// Kullanıcı tıklamasında eşzamanlı çalışır; kilitliyken giriş açılmaz.
  void posGirisiniAc(DenemeSonucu sonuc) {
    if (_kapali || kilitli) {
      throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden kart seçin.');
    }
    servis.girisiAc(sonuc);
  }

  @override
  void dispose() {
    _kapali = true;
    // Kapanışta bağlantı kesilmişse iptal de hata verebilir; sahipsiz hata bırakılmaz.
    _izleme?.cancel().catchError((Object _) {});
    _nesil++;
    super.dispose();
  }
}
