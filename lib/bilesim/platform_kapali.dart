import '../application/kart_kasasi.dart';
import '../application/portlar.dart';
import '../application/tahsilat_servisi.dart';
import 'baglantilar.dart';

/// Cihaz özelliği olmayan ortam: kart kasası, DenizPay girişi, yer imi ve dosya
/// indirme kapalıdır; ekranlar bunu `destekli` ile görür.
const platformBaglantilari = PlatformBaglantilari(
  kartKasasi: KapaliKartKasasi(),
  girisKapisi: KapaliPosGirisKapisi(),
  doldurma: KapaliDoldurmaHazirligi(),
  acikGiris: KapaliAcikGiris(),
  sonucKutusu: KapaliSonucKutusu(),
  indirici: KapaliDosyaIndirici(),
);
