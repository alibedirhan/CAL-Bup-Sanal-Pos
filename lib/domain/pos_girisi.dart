import 'hata.dart';

/// Kullanıcının bildirdiği sağlayıcı giriş kuralı. Hesap şifresi değildir.
/// Yalnız açık kopyalama veya giriş isteğinde hesaplanır; depoya/loga/URL'ye yazılmaz.
String posGirisSifresi(String kimlikNo) {
  if (!RegExp(r'^[0-9]{10,11}$').hasMatch(kimlikNo)) {
    throw const PosHatasi('kimlik', 'Önce geçerli VKN / TC numarası ekle.');
  }
  return kimlikNo.substring(0, 2) + kimlikNo.substring(kimlikNo.length - 2);
}

/// Sağlayıcı giriş formuna giden üç değer. Kullanıcı adı varsayılan kuralla
/// VKN/TC numarasıdır. Nesne saklanmaz; yalnız giriş tıklamasında üretilir.
class PosGirisBilgisi {
  const PosGirisBilgisi._(this.vergiNo, this.kullanici, this.sifre);
  factory PosGirisBilgisi.kimlikten(String kimlikNo) {
    final sifre = posGirisSifresi(kimlikNo);
    return PosGirisBilgisi._(kimlikNo, kimlikNo, sifre);
  }
  final String vergiNo, kullanici, sifre;

  @override
  String toString() => 'PosGirisBilgisi(gizli)';
}
