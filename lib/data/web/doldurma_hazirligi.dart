import 'dart:convert';
import 'dart:js_interop';
import '../../application/portlar.dart';
import '../../domain/doldurma.dart';
import '../../domain/hata.dart';

@JS('bupDoldurma')
external JSObject? get _modul;
@JS('bupDoldurma.hazirla')
external JSString _hazirla(JSString is_);
@JS('bupDoldurma.temizle')
external JSString _temizle();

/// `web/doldurma.js` işi bu kökenin yerel deposuna yazar; DenizPay'deki yer
/// iminin açtığı `doldur.html` okur. İşte tam kart yoktur.
class WebDoldurmaHazirligi implements DoldurmaHazirligi {
  const WebDoldurmaHazirligi();
  @override
  bool get destekli => _modul != null;
  @override
  void hazirla(DoldurmaIsi is_) {
    try {
      if (_hazirla(jsonEncode(is_.toJson()).toJS).toDart != 'ok') {
        throw StateError('doldurma');
      }
    } catch (_) {
      throw const PosHatasi(
        'doldurma',
        'Kart doldurma hazırlanamadı. Giriş yapıp kart bilgilerini elle yaz.',
      );
    }
  }

  @override
  void temizle() {
    if (_modul != null) _temizle();
  }
}
