import '../application/biyometrik_kilit.dart';
import '../application/kart_kasasi.dart';
import '../application/pin_kapisi.dart';
import '../application/portlar.dart';
import '../application/rota_kurulumu.dart';
import '../application/surum_denetimi.dart';
import '../application/tahsilat_servisi.dart';
import '../ui/denizpay_ekrani.dart';
import '../ui/kart_tarama_ekrani.dart';

/// Bir platformun (web, Android) cihaza bağlı bağdaştırıcıları. Servisler ve
/// ekranlar bunları yalnız port olarak görür; hangisinin kullanılacağı derlemede
/// `platform.dart` ile seçilir.
class PlatformBaglantilari {
  const PlatformBaglantilari({
    required this.kartKasasi,
    required this.girisKapisi,
    required this.doldurma,
    required this.acikGiris,
    required this.sonucKutusu,
    required this.indirici,
    this.biyometri = const KapaliBiyometrikKilit(),
    this.acilistaKilit = false,
    this.denizPayAcici,
    this.uygulamaSurumu = const KapaliUygulamaSurumu(),
    this.pinKapisi,
    this.kartTarayici,
    this.rotaKurulumu,
  });
  final KartKasasi kartKasasi;
  final PosGirisKapisi girisKapisi;
  final DoldurmaHazirligi doldurma;
  final AcikGirisPortu acikGiris;
  final SonucKutusu sonucKutusu;
  final DosyaIndirici indirici;
  final BiyometrikKilit biyometri;

  /// Hesap oturumu uygulama kapanınca da sürüyorsa (Android) açılış kilitli
  /// olur: şifre veya biyometri gerekir. Web'de oturum yalnız sekmededir.
  final bool acilistaKilit;

  /// Uygulama içi DenizPay ekranı (Android). `null`: web'deki gibi ayrı sekme.
  final DenizPayAcici? denizPayAcici;

  /// Kurulu uygulamanın sürümü (Android); web'de sürüm denetimi yoktur.
  final UygulamaSurumuPortu uygulamaSurumu;

  /// Ekran kilidi olmayan Android telefonda kart kasasının uygulama PIN'i;
  /// açık uygulama ekranı pencereyi gösterir. Web'de yok.
  final PinKapisi? pinKapisi;

  /// Karttan okuma (Android: NFC, kamera). Web'de yapıştırma kutusu yeter.
  final KartTarayicilari? kartTarayici;

  /// Konum kurulumu (Android rota hizmeti, docs/ROTA_MIMARI.md M16). Web'de yok.
  final RotaKurulumPortu? rotaKurulumu;
}
