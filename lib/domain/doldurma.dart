import 'hata.dart';
import 'modeller.dart';

/// DenizPay kart sayfasındaki yer iminin bu cihazda okuyacağı bekleyen iş.
/// Sır içermez: tam kart cihaz kasasında şifreli kalır, iş yalnız kasa
/// kaydının referansıdır. Tutar, CVV, OTP ve giriş şifresi hiçbir zaman
/// alan olarak bulunmaz (docs/MOBIL_DOLDURMA_PLANI.md, Aşama 2).
class DoldurmaIsi {
  DoldurmaIsi({
    required this.kullaniciId,
    required this.kart,
    required this.kimlikNo,
    required this.son,
  }) {
    if (kullaniciId.isEmpty ||
        kart.cihazKayitId == null ||
        kart.cihazKayitId!.isEmpty ||
        !RegExp(r'^[0-9]{10,11}$').hasMatch(kimlikNo)) {
      throw const PosHatasi(
        'doldurma',
        'Bu kart için doldurma hazırlanamadı. Kartı bu cihazda yeniden kaydet.',
      );
    }
  }

  static const sure = Duration(minutes: 10);
  final String kullaniciId, kimlikNo;
  final KartOzeti kart;
  final DateTime son;

  /// `web/doldur_sayfasi.js` ve `web/kart_kasasi.js` bu biçimi bekler.
  Map<String, Object> toJson() => {
    'v': 1,
    'uid': kullaniciId,
    'kimlikNo': kimlikNo,
    'son': son.millisecondsSinceEpoch,
    'kart': {
      'id': kart.id,
      'cariId': kart.cariId,
      'sonDort': kart.sonDort,
      'ay': kart.ay,
      'yil': kart.yil,
      'cihazKayitId': kart.cihazKayitId!,
    },
  };
}
