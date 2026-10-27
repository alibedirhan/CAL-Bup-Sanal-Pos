import 'dart:convert';
import 'dart:js_interop';
import '../../application/kart_kasasi.dart';
import '../../domain/hata.dart';
import '../../domain/kart_bilgileri.dart';
import '../../domain/modeller.dart';

@JS('bupKartKasasi.hazirla')
external JSPromise<JSString> _hazirla(
  JSString uid,
  JSString meta,
  JSString veri,
);
@JS('bupKartKasasi.tamamla')
external JSPromise<JSString> _tamamla(JSString uid, JSString kayitId);
@JS('bupKartKasasi.oku')
external JSPromise<JSString> _oku(JSString uid, JSString meta);
@JS('bupKartKasasi.sil')
external JSPromise<JSString> _sil(JSString uid, JSString cari, JSString? kart);

class WebKartKasasi implements KartKasasi {
  const WebKartKasasi();
  Future<dynamic> _dene(JSPromise<JSString> Function() f) async {
    try {
      final r =
          jsonDecode(
                (await f().toDart.timeout(const Duration(seconds: 10))).toDart,
              )
              as Map;
      if (r['ok'] != true) throw StateError('cihaz');
      return r['value'];
    } catch (_) {
      throw const PosHatasi(
        'cihaz',
        'Bu cihazdaki şifreli kart bilgisine ulaşılamadı. Tarayıcının saklama iznini kontrol et; kayıtlarını silme.',
      );
    }
  }

  JSString _meta(KartOzeti k) => jsonEncode({
    'id': k.id,
    'cariId': k.cariId,
    'sonDort': k.sonDort,
    'ay': k.ay,
    'yil': k.yil,
    'cihazKayitId': k.cihazKayitId,
  }).toJS;
  @override
  Future<String> hazirla(
    String uid,
    KartOzeti kart,
    KartBilgileri bilgiler,
  ) async =>
      await _dene(
            () => _hazirla(
              uid.toJS,
              _meta(kart),
              jsonEncode({
                'numara': bilgiler.numara,
                'sahibi': bilgiler.sahibi,
                'telefon': bilgiler.telefon,
              }).toJS,
            ),
          )
          as String;
  @override
  Future<void> tamamla(String uid, String kayitId) async {
    await _dene(() => _tamamla(uid.toJS, kayitId.toJS));
  }

  @override
  Future<KartBilgileri?> oku(String uid, KartOzeti kart) async {
    final text = await _dene(() => _oku(uid.toJS, _meta(kart))) as String?;
    if (text == null) return null;
    try {
      final d = jsonDecode(text) as Map;
      return KartBilgileri(
        numara: d['numara'] as String,
        sahibi: d['sahibi'] as String,
        telefon: d['telefon'] as String,
      );
    } catch (_) {
      throw const PosHatasi(
        'cihaz',
        'Bu cihazdaki kart kaydı açılamadı. Kayıt değiştirilmedi.',
      );
    }
  }

  @override
  Future<void> sil(String uid, String cariId, String? kartId) async {
    await _dene(() => _sil(uid.toJS, cariId.toJS, kartId?.toJS));
  }
}
