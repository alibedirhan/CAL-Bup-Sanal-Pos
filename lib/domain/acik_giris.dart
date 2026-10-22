import 'tahsilat.dart';

/// Bu cihazda son açılan DenizPay girişi. DenizPay sonuç ekranında "BUP Doldur"
/// yer iminin açtığı `sonuc.html` sonucu bu cariye bağlar (`web/acik_giris.js`).
/// Sır içermez: kart numarası, şifre, CVV yoktur. Her yeni girişte değişir;
/// çıkış/hesap değişimi ve "Boş giriş sayfasını aç" siler.
class AcikGiris {
  const AcikGiris(this.giris, this.son);

  /// SMS beklemesi ve yeniden deneme için uzun tutulur; yine de sınırlıdır.
  static const sure = Duration(hours: 2);
  final PosGirisi giris;
  final DateTime son;

  /// `web/acik_giris.js` ve `web/sonuc_sayfasi.js` bu biçimi bekler.
  Map<String, Object> toJson() => {
    'v': 1,
    'uid': giris.kullaniciId,
    'girisId': giris.id,
    'cariId': giris.cariId,
    'cariAd': giris.cariAd,
    'kimlikNo': giris.kimlikNo,
    'kartSonDort': giris.kartSonDort,
    'son': son.millisecondsSinceEpoch,
  };
}
