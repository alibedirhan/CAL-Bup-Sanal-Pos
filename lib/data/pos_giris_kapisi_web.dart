import 'dart:js_interop';
import '../application/portlar.dart';
import '../domain/hata.dart';
import '../domain/pos_girisi.dart';

@JS('bupPosGiris')
external JSObject? get _modul;
@JS('bupPosGiris.ac')
external JSString _ac(JSString vergiNo, JSString kullanici, JSString sifre);

/// `web/pos_giris.js` sabit DenizPay giriş adresine geçici form gönderir.
class CihazPosGirisKapisi implements PosGirisKapisi {
  const CihazPosGirisKapisi();
  @override
  bool get destekli => _modul != null;
  @override
  void ac(PosGirisBilgisi giris) {
    try {
      if (_ac(
            giris.vergiNo.toJS,
            giris.kullanici.toJS,
            giris.sifre.toJS,
          ).toDart !=
          'ok') {
        throw StateError('pos_giris');
      }
    } catch (_) {
      throw const PosHatasi(
        'giris',
        'Giriş sayfası açılamadı. Boş giriş sayfasını açıp bilgileri elle gir.',
      );
    }
  }
}
