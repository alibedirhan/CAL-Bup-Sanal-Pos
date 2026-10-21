import '../domain/doldurma.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/pos_girisi.dart';

/// Canlı adaptör kimliği doğrulanmış oturumu kullanmalı, erişimi sunucuda
/// denetlemeli ve sürüm denetimini atomik uygulamalıdır. İstemci kontrolü yetmez.
abstract interface class CariDeposu {
  Future<List<CariOzeti>> listele(String kullaniciId);
  Future<CariProfili> profil(String kullaniciId, String cariId);
  Future<Cari> ekle(
    String kullaniciId,
    String ad,
    String kod, {
    String kimlikNo = '',
  });
  Future<void> kaydet(String kullaniciId, Cari cari, int beklenenSurum);
  Future<void> sil(String kullaniciId, String cariId, int beklenenSurum);
  Future<void> denemeKartiEkle(String kullaniciId, String cariId);
  Future<void> kartKaydet(
    String kullaniciId,
    String cariId,
    int beklenenSurum,
    KartOzeti kart,
  );
  Future<void> kartSil(
    String kullaniciId,
    String cariId,
    int beklenenSurum,
    String kartId,
  );
}

abstract interface class PosBaglantisi {
  Future<DenemeSonucu> dene(Cari cari, KartOzeti kart);
}

abstract interface class CariIzlemePortu {
  Stream<List<CariOzeti>> izle(String kullaniciId);
}

/// Sağlayıcı giriş sayfasını kullanıcının tıklamasıyla açar. Tarayıcının açılır
/// pencere iznini kaybetmemek için eşzamanlıdır; yanıt/sonuç okunmaz.
abstract interface class PosGirisKapisi {
  bool get destekli;
  void ac(PosGirisBilgisi giris);
}

/// Kart sayfası yer iminin okuyacağı bekleyen işi bu cihazda tutar. Eşzamanlıdır;
/// kilit, çıkış ve kartsız girişte temizlenir.
abstract interface class DoldurmaHazirligi {
  bool get destekli;
  void hazirla(DoldurmaIsi is_);
  void temizle();
}

class KapaliDoldurmaHazirligi implements DoldurmaHazirligi {
  const KapaliDoldurmaHazirligi();
  @override
  bool get destekli => false;
  @override
  void hazirla(DoldurmaIsi is_) {}
  @override
  void temizle() {}
}

class KapaliPosGirisKapisi implements PosGirisKapisi {
  const KapaliPosGirisKapisi();
  @override
  bool get destekli => false;
  @override
  void ac(PosGirisBilgisi giris) => throw const PosHatasi(
    'giris_yok',
    'Otomatik giriş bu cihazda kullanılamıyor.',
  );
}
