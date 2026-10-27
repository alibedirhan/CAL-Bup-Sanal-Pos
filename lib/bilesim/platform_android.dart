import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../application/denizpay_oturumu.dart';
import '../application/portlar.dart';
import '../application/tahsilat_servisi.dart';
import '../data/android/biyometrik_kilit.dart';
import '../data/android/denizpay_tarayicisi.dart';
import '../data/android/dosya_indirici.dart';
import '../data/android/kart_kasasi.dart';
import '../data/android/sonuc_kutusu.dart';
import '../data/android/uygulama_surumu.dart';
import '../data/kasa/sifreli_kasa.dart';
import '../domain/denizpay.dart';
import '../domain/kart_bilgileri.dart';
import '../ui/denizpay_ekrani.dart';
import 'baglantilar.dart';
import 'platform_kapali.dart' show kapaliBaglantilar;

/// Android uygulaması: Keystore kart kasası, parmak izi/yüz kilidi, "Kaydet"
/// penceresi, uygulama içi DenizPay (docs/ANDROID_PLANI.md §3); oturum kalıcı
/// olduğu için açılış kilitli. Web yer imi ve ayrı sekme girişi kullanılmaz.
/// Android dışında (Dart testleri, masaüstü) kapalı bağdaştırıcılar.
final PlatformBaglantilari platformBaglantilari = Platform.isAndroid
    ? PlatformBaglantilari(
        kartKasasi: SifreliKasa(const KeystoreSifreleyici(), DosyaKasaDeposu()),
        girisKapisi: const KapaliPosGirisKapisi(),
        doldurma: const KapaliDoldurmaHazirligi(),
        acikGiris: const KapaliAcikGiris(),
        sonucKutusu: _kutu,
        indirici: const AndroidDosyaIndirici(),
        biyometri: AndroidBiyometrikKilit(),
        acilistaKilit: true,
        denizPayAcici: _denizPayAc,
        uygulamaSurumu: const AndroidUygulamaSurumu(),
      )
    : kapaliBaglantilar;

/// DenizPay ekranının bıraktığı ve tahsilat servisinin yazdığı sonuçların tek kutusu.
final _kutu = AndroidSonucKutusu();

/// Canlıda yalnız gerçek DenizPay. Taklit köken yalnız emülatör derlemesinde
/// (`BUP_EMULATOR`) kabul edilir; yayın kapısı canlı pakette bunu denetler.
final DenizPayAdresi _adres = () {
  const emulator = bool.fromEnvironment('BUP_EMULATOR');
  const taklit = String.fromEnvironment('BUP_DENIZPAY_KOKENI');
  return emulator && taklit.isNotEmpty
      ? DenizPayAdresi(Uri.parse(taklit))
      : DenizPayAdresi.canli;
}();

Future<void> _denizPayAc(
  BuildContext context,
  DenizPayBaglami baglam,
  Future<KartBilgileri?> Function() kartiOku,
) {
  late final DenizPayOturumu oturum;
  final tarayici = AndroidDenizPayTarayicisi(
    _adres,
    yuklendi: (u) => oturum.sayfaYuklendi(u),
  );
  oturum = DenizPayOturumu(
    baglam: baglam,
    tarayici: tarayici,
    adres: _adres,
    birakma: _kutu,
    kartiOku: kartiOku,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DenizPayEkrani(oturum: oturum, gorunum: tarayici.gorunum),
    ),
  );
}
