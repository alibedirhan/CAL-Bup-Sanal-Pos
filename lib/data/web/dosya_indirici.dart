import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../application/tahsilat_servisi.dart';

/// Tarayıcının kendi indirmesiyle kaydeder; dosya ağa gönderilmez.
class WebDosyaIndirici implements DosyaIndirici {
  const WebDosyaIndirici();
  @override
  bool get destekli => true;
  @override
  Future<DosyaSonucu> indir(String dosyaAdi, String icerik) async {
    final blob = web.Blob(
      [icerik.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final adres = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = adres
      ..download = dosyaAdi;
    web.document.body!.append(a);
    a.click();
    a.remove();
    // iOS indirme sorusunu gösterirken adres hâlâ geçerli olmalı.
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(adres));
    return DosyaSonucu.indirildi;
  }
}
