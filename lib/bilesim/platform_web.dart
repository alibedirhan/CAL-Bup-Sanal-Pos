import '../data/web/acik_giris.dart';
import '../data/web/doldurma_hazirligi.dart';
import '../data/web/dosya_indirici.dart';
import '../data/web/kart_kasasi.dart';
import '../data/web/pos_giris_kapisi.dart';
import '../data/web/sonuc_kutusu.dart';
import 'baglantilar.dart';

/// Tarayıcı paketi: `web/*.js` köprüleri (kart kasası, DenizPay girişi, yer imi
/// işi, açık girişler, sonuç kutusu) ve tarayıcı indirmesi.
const platformBaglantilari = PlatformBaglantilari(
  kartKasasi: WebKartKasasi(),
  girisKapisi: WebPosGirisKapisi(),
  doldurma: WebDoldurmaHazirligi(),
  acikGiris: WebAcikGiris(),
  sonucKutusu: WebSonucKutusu(),
  indirici: WebDosyaIndirici(),
);
