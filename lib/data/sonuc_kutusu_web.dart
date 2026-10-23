import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import '../application/tahsilat_servisi.dart';

@JS('bupSonucKutusu')
external JSObject? get _modul;
@JS('bupSonucKutusu.oku')
external JSString _oku();
@JS('bupSonucKutusu.sil')
external JSString _sil(JSString kimlik);
@JS('bupSonucKutusu.yanitla')
external JSString _yanitla(JSString yanit);
@JS('bupSonucKutusu.dinle')
external JSString _dinle(JSFunction geri);

// Sayfa başına tek dinleyici: kilit/yeniden girişte yeni bağdaştırıcı eklenmez.
final _degisim = StreamController<void>.broadcast();
var _dinleniyor = false;

/// `web/sonuc_kutusu.js`: sonuç sayfasının bu kökenin yerel deposuna bıraktığı
/// sonuçlar. Okuma/silme hatası işi durdurmaz; sonuç kutuda kalır.
class CihazSonucKutusu implements SonucKutusu {
  const CihazSonucKutusu();
  @override
  bool get destekli => _modul != null;

  @override
  List<Map<String, Object?>> oku() {
    if (!destekli) return const [];
    try {
      return [
        for (final e in jsonDecode(_oku().toDart) as List)
          if (e is Map) e.cast<String, Object?>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  void sil(String kimlik) {
    try {
      if (destekli) _sil(kimlik.toJS);
    } catch (_) {}
  }

  @override
  void yanitla(String kimlik, {required bool tamam, required String mesaj}) {
    try {
      if (destekli) {
        _yanitla(
          jsonEncode({
            'kimlik': kimlik,
            'tamam': tamam,
            'mesaj': mesaj,
            // Aynı yanıt ikinci kez yazılınca da depo olayı oluşsun.
            'an': DateTime.now().millisecondsSinceEpoch,
          }).toJS,
        );
      }
    } catch (_) {}
  }

  @override
  Stream<void> get degisimler {
    if (!_dinleniyor && destekli) {
      _dinleniyor = true;
      _dinle((() => _degisim.add(null)).toJS);
    }
    return _degisim.stream;
  }
}
