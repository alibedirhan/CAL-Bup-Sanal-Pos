import '../application/biyometrik_kilit.dart';
import '../application/kart_kasasi.dart';
import '../application/portlar.dart';
import '../application/tahsilat_servisi.dart';

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
}
