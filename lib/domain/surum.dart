/// Android uygulamasının sürüm denetimi (docs/ANDROID_PLANI.md, Aşama 3).
/// Sunucudaki `ayarlar/android` belgesini yalnız yönetici aracı yazar
/// (firestore.rules: istemci yazamaz). Sürüm numaraları Android `versionCode`'dur.
class AndroidSurumu {
  const AndroidSurumu({
    required this.enDusuk,
    required this.son,
    required this.sonAd,
    required this.indirme,
    required this.sha256,
  });

  /// Bunun altındaki sürüm açılmaz ("Güncelleme gerekli").
  final int enDusuk;

  /// Yayındaki en yeni sürüm; altındaki sürüm açılışta not gösterir.
  final int son;

  /// [son]'un okunur adı (ör. "0.11.0").
  final String sonAd;

  /// Kurulum sayfası (yalnız https).
  final Uri indirme;

  /// Yayındaki APK dosyasının SHA-256 özeti (küçük harf, 64 onaltılık).
  final String sha256;

  static final _ad = RegExp(r'^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$');
  static final _ozet = RegExp(r'^[0-9a-f]{64}$');

  /// Eksik, fazla alanlı veya tutarsız belge `null` olur: denetim yapılmaz,
  /// uygulama açılır (yazma yetkisi zaten sunucuda denetlenir).
  static AndroidSurumu? coz(Object? d) {
    if (d is! Map || d.length != 5) return null;
    final enDusuk = d['enDusuk'], son = d['son'], sonAd = d['sonAd'];
    final indirme = d['indirme'], sha256 = d['sha256'];
    if (enDusuk is! int ||
        son is! int ||
        enDusuk < 1 ||
        son < enDusuk ||
        sonAd is! String ||
        !_ad.hasMatch(sonAd) ||
        sha256 is! String ||
        !_ozet.hasMatch(sha256) ||
        indirme is! String ||
        indirme.length > 300) {
      return null;
    }
    final adres = Uri.tryParse(indirme);
    if (adres == null ||
        adres.scheme != 'https' ||
        adres.host.isEmpty ||
        adres.userInfo.isNotEmpty ||
        adres.hasPort) {
      return null;
    }
    return AndroidSurumu(
      enDusuk: enDusuk,
      son: son,
      sonAd: sonAd,
      indirme: adres,
      sha256: sha256,
    );
  }
}

enum SurumDurumu {
  /// Güncel ya da denetlenemedi (çevrimdışı, belge yok/bozuk, web).
  guncel,

  /// Daha yeni sürüm var; uygulama açılır, not gösterilir.
  guncellemeVar,

  /// Bu sürüm artık kullanılamaz; yalnız indirme ve çıkış.
  guncellemeGerekli,
}

class SurumSonucu {
  const SurumSonucu(this.durum, {this.mevcut, this.bilgi});
  static const guncel = SurumSonucu(SurumDurumu.guncel);
  final SurumDurumu durum;

  /// Bu uygulamanın `versionCode`'u; denetlenmediyse `null`.
  final int? mevcut;
  final AndroidSurumu? bilgi;

  static SurumSonucu karar(int mevcut, AndroidSurumu? bilgi) => SurumSonucu(
    bilgi == null || mevcut >= bilgi.son
        ? SurumDurumu.guncel
        : mevcut < bilgi.enDusuk
        ? SurumDurumu.guncellemeGerekli
        : SurumDurumu.guncellemeVar,
    mevcut: mevcut,
    bilgi: bilgi,
  );
}
