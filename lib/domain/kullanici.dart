import 'hata.dart';
import 'modeller.dart';

class Kullanici {
  Kullanici({
    required this.id,
    required String ad,
    required this.eposta,
    required this.yonetici,
    required this.aktif,
  }) : ad = duzMetin(ad, enAz: 2, enFazla: 80);
  final String id, ad, eposta;
  final bool yonetici, aktif;
}

/// Hesap profili dinlenirken hata geldiğinde oturum (ekran) kapanır mı?
///
/// Profil yalnız sunucudan doğrulanmış olarak kabul edilir; telefonun önbelleğinden
/// gelen kayıt `baglanti` hatası sayılır. Bağlantı bir an tazelenince (şifre yeniden
/// doğrulanınca, tünel, kapsama dışı) Firestore araya önbellek kaydı koyar: zaten
/// doğrulanmış kullanıcı bunun için ekrandan atılmaz, açık sayfaları kaybolmaz
/// (17 Kasım 2026, gerçek telefonda görüldü). İlk doğrulama henüz yoksa ve başka her
/// hatada oturum eskisi gibi kapanır; sunucudan gelen "erişim kapalı" kaydı her zaman
/// hemen uygulanır (o hata değil, veri olarak gelir).
bool profilHatasiOturumuKapatir(
  Object hata, {
  required bool dogrulanmisKullaniciVar,
}) => !(dogrulanmisKullaniciVar && hata is PosHatasi && hata.kod == 'baglanti');
