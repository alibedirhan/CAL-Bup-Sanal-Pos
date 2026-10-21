import '../domain/modeller.dart';

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
