import 'dart:convert';
import 'dart:js_interop';
import '../application/tahsilat_servisi.dart';
import '../domain/acik_giris.dart';

@JS('bupAcikGiris')
external JSObject? get _modul;
@JS('bupAcikGiris.hazirla')
external JSString _hazirla(JSString acik);
@JS('bupAcikGiris.temizle')
external JSString _temizle();

/// `web/acik_giris.js` son girişi bu kökenin yerel deposuna yazar; DenizPay
/// sonuç ekranındaki yer iminin açtığı `sonuc.html` okur.
class CihazAcikGiris implements AcikGirisPortu {
  const CihazAcikGiris();
  @override
  bool get destekli => _modul != null;
  @override
  void hazirla(AcikGiris acik) {
    if (_hazirla(jsonEncode(acik.toJson()).toJS).toDart != 'ok') {
      throw StateError('acik_giris');
    }
  }

  @override
  void temizle() {
    if (_modul != null) _temizle();
  }
}
