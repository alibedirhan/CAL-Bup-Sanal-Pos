import '../application/portlar.dart';
import '../domain/modeller.dart';

/// Yalnız güncel seçimi doğrular. Ödeme veya sağlayıcıya veri aktarımı yapmaz.
class SecimKontrolu implements PosBaglantisi {
  const SecimKontrolu();
  @override
  Future<DenemeSonucu> dene(Cari cari, KartOzeti kart) async =>
      DenemeSonucu(cari.ad, kart.sonDort);
}
