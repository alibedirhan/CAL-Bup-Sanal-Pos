import 'hata.dart';

/// Kullanıcının bildirdiği sağlayıcı giriş kuralı. Hesap şifresi değildir.
/// Yalnız açık kopyalama isteğinde hesaplanır; depoya/loga/URL'ye yazılmaz.
String posGirisSifresi(String kimlikNo) {
  if (!RegExp(r'^[0-9]{10,11}$').hasMatch(kimlikNo)) {
    throw const PosHatasi('kimlik', 'Önce geçerli VKN / TC numarası ekle.');
  }
  return kimlikNo.substring(0, 2) + kimlikNo.substring(kimlikNo.length - 2);
}
