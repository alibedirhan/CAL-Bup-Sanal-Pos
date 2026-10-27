import '../domain/surum.dart';

/// Bu uygulamanın kendi sürümü. `null`: sürüm denetimi olmayan platform (web).
abstract interface class UygulamaSurumuPortu {
  Future<int?> kod();
}

/// Sunucudaki `ayarlar/android` belgesi; yoksa `null`.
abstract interface class SurumAyariPortu {
  Future<Object?> oku();
}

class KapaliUygulamaSurumu implements UygulamaSurumuPortu {
  const KapaliUygulamaSurumu();
  @override
  Future<int?> kod() async => null;
}

/// Açılışta ve kilit açılınca bir kez sorulur. Denetim uygulamayı yalnız
/// sunucu açıkça "en düşük sürümün altında" dediğinde durdurur; okunamayan,
/// geç gelen veya bozuk belge engellemez (çevrimdışı açılış sürer).
class SurumDenetimi {
  SurumDenetimi({
    required this.uygulama,
    required this.ayar,
    this.sure = const Duration(seconds: 8),
  });
  final UygulamaSurumuPortu uygulama;
  final SurumAyariPortu ayar;
  final Duration sure;

  Future<SurumSonucu> denetle() async {
    try {
      final mevcut = await uygulama.kod();
      if (mevcut == null) return SurumSonucu.guncel;
      final belge = await ayar.oku().timeout(sure);
      return SurumSonucu.karar(mevcut, AndroidSurumu.coz(belge));
    } catch (_) {
      return SurumSonucu.guncel;
    }
  }
}
