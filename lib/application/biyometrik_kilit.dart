/// Ekran kilidinin parmak izi/yüzle açılması. Yalnız destekleyen platformda
/// (Android) vardır; diğerlerinde [KapaliBiyometrikKilit]. Biyometri hesap
/// şifresinin yerine geçmez: kilidi açtıktan sonra hesap yetkisi sunucudan
/// yeniden okunur. Kurallar `domain/biyometri.dart`'tadır.
abstract interface class BiyometrikKilit {
  /// Bu hesap için şimdi biyometriyle açılabilir mi (cihaz, kayıt ve kurallar).
  Future<bool> kullanilabilir(String uid);

  /// Hesap şifresi bu telefonda doğrulandı: süre yenilenir; cihaz destekliyorsa
  /// biyometri etkinleşir. Hata kilidi açmayı engellemez (sessiz, şifre kalır).
  Future<void> sifreDogrulandi(String uid);

  /// Biyometri penceresi. [BiyometriSonucu.sifreGerekli] dönerse kayıt silinmiştir.
  Future<BiyometriSonucu> dogrula(String uid);

  /// Çıkış veya hesap değişimi: bu telefondaki biyometri kaydı ve anahtarı silinir.
  Future<void> unut(String uid);
}

enum BiyometriSonucu {
  tamam,

  /// Kişi pencereyi kapattı veya "Şifreyle aç"a bastı.
  iptal,

  /// Yeni parmak izi/yüz eklendi, telefon yeniden başladı, süre doldu ya da çok
  /// fazla hatalı deneme: hesap şifresi gerekir.
  sifreGerekli,
  hata,
}

class KapaliBiyometrikKilit implements BiyometrikKilit {
  const KapaliBiyometrikKilit();
  @override
  Future<bool> kullanilabilir(String uid) async => false;
  @override
  Future<void> sifreDogrulandi(String uid) async {}
  @override
  Future<BiyometriSonucu> dogrula(String uid) async =>
      BiyometriSonucu.sifreGerekli;
  @override
  Future<void> unut(String uid) async {}
}
