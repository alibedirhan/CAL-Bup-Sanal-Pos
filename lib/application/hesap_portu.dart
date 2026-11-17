import '../domain/kullanici.dart';
import '../domain/modeller.dart';

abstract interface class HesapPortu {
  Stream<String?> get degisimler;
  String? get kimlik;
  Future<void> giris(String eposta, String parola);
  Future<void> cikis();
  Future<void> parolaSifirla(String eposta);
  Future<void> parolaDegistir(String mevcut, String yeni);

  /// Hassas yönetici işinden önce şifre yeniden sorulur (ör. konum kurulumu).
  Future<void> yenidenDogrula(String parola);
  Future<Kullanici> profil();
  Stream<Kullanici?> profilIzle();
}

abstract interface class YonetimPortu {
  Future<List<Kullanici>> kullanicilar();
  Future<List<CariOzeti>> cariler();
  Future<void> hesapAc(String ad, String eposta, String geciciParola);
  Future<void> erisimDegistir(Kullanici kullanici, bool aktif);
  Future<void> ata(String cariId, int surum, String yeniSahip);
}
