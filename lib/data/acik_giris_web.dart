import 'dart:convert';
import 'dart:js_interop';
import '../application/tahsilat_servisi.dart';
import '../domain/acik_giris.dart';

@JS('bupAcikGiris')
external JSObject? get _modul;
@JS('bupAcikGiris.ekle')
external JSString _ekle(JSString acik);
@JS('bupAcikGiris.temizle')
external JSString _temizle();
@JS('bupAcikGiris.yalniz')
external JSString _yalniz(JSString uid);

/// `web/acik_giris.js` girişi bu kökenin yerel deposundaki listeye ekler;
/// DenizPay sonuç ekranındaki yer iminin açtığı `sonuc.html` okur.
class CihazAcikGiris implements AcikGirisPortu {
  const CihazAcikGiris();
  @override
  bool get destekli => _modul != null;
  @override
  void ekle(AcikGiris acik) {
    if (_ekle(jsonEncode(acik.toJson()).toJS).toDart != 'ok') {
      throw StateError('acik_giris');
    }
  }

  @override
  void temizle() {
    if (_modul != null) _temizle();
  }

  /// Giriş yapan hesabın dışındaki girişleri siler.
  void yalniz(String uid) {
    if (_modul != null) _yalniz(uid.toJS);
  }
}
