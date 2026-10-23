import 'tahsilat.dart';

/// Bu cihazda açılan bir DenizPay girişi (`web/acik_giris.js` son 10 girişi
/// [sure] boyunca tutar). DenizPay sonuç ekranında "BUP Doldur" yer iminin
/// açtığı `sonuc.html` sonucu bu girişlerden birine bağlar
/// (`web/cari_eslestir.js`). Sır içermez: kart numarası, şifre, CVV yoktur.
/// Bu sekmede çıkış ve "Boş giriş sayfasını aç" hepsini siler; başka hesapla
/// girişte o hesabın girişleri atılır (yeni sekmenin oturumsuz açılışı silmez).
class AcikGiris {
  const AcikGiris(this.giris, this.an);

  /// SMS beklemesi ve yeniden deneme için uzun tutulur; yine de sınırlıdır.
  static const sure = Duration(hours: 2);
  final PosGirisi giris;

  /// "DenizPay'e giriş yap"a basıldığı an (telefon saati).
  final DateTime an;
  DateTime get son => an.add(sure);

  /// `web/acik_giris.js` ve `web/sonuc_sayfasi.js` bu biçimi bekler.
  Map<String, Object> toJson() => {
    'v': 2,
    'uid': giris.kullaniciId,
    'girisId': giris.id,
    'cariId': giris.cariId,
    'cariAd': giris.cariAd,
    'kimlikNo': giris.kimlikNo,
    'kartSonDort': giris.kartSonDort,
    'an': an.millisecondsSinceEpoch,
    'son': son.millisecondsSinceEpoch,
  };
}
