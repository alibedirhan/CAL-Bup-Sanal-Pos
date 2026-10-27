import 'dart:io' show Platform;
import '../application/portlar.dart';
import '../application/tahsilat_servisi.dart';
import '../data/android/biyometrik_kilit.dart';
import '../data/android/dosya_indirici.dart';
import '../data/android/kart_kasasi.dart';
import '../data/kasa/sifreli_kasa.dart';
import 'baglantilar.dart';
import 'platform_kapali.dart' show kapaliBaglantilar;

/// Android uygulaması: Keystore kart kasası, parmak izi/yüz kilidi, "Kaydet"
/// penceresi; oturum kalıcı olduğu için açılış kilitli. DenizPay girişi ve
/// sonuç kaydı Aşama 2'de uygulama içi ekranla gelir (docs/ANDROID_PLANI.md §3);
/// o zamana kadar kapalıdır. Android dışında (Dart testleri, masaüstü) kapalı.
final PlatformBaglantilari platformBaglantilari = Platform.isAndroid
    ? PlatformBaglantilari(
        kartKasasi: SifreliKasa(const KeystoreSifreleyici(), DosyaKasaDeposu()),
        girisKapisi: const KapaliPosGirisKapisi(),
        doldurma: const KapaliDoldurmaHazirligi(),
        acikGiris: const KapaliAcikGiris(),
        sonucKutusu: const KapaliSonucKutusu(),
        indirici: const AndroidDosyaIndirici(),
        biyometri: AndroidBiyometrikKilit(),
        acilistaKilit: true,
      )
    : kapaliBaglantilar;
