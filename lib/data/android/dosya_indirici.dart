import '../../application/tahsilat_servisi.dart';
import 'kanal.dart';

/// Android "Kaydet" penceresi: kişi yeri ve adı seçer (İndirilenler, Drive…).
/// Dosya başka uygulamaya paylaşılmaz; yalnız seçilen yere yazılır.
class AndroidDosyaIndirici implements DosyaIndirici {
  const AndroidDosyaIndirici();
  @override
  bool get destekli => true;
  @override
  Future<DosyaSonucu> indir(String dosyaAdi, String icerik) async {
    final r = await guvenlikKanali.invokeMethod<String>('dosya.kaydet', {
      'ad': dosyaAdi,
      'icerik': icerik,
    });
    return switch (r) {
      'kaydedildi' => DosyaSonucu.kaydedildi,
      'vazgecildi' => DosyaSonucu.vazgecildi,
      _ => throw StateError('dosya'),
    };
  }
}
