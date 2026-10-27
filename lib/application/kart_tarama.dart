import '../domain/kart_okuma.dart';

/// Karttan okuma yolları (Android, 0.12.0). Okunan bilgi yalnız forma yazılır;
/// kişi karşılaştırıp kaydeder. CVV hiçbir yoldan okunmaz.
enum TaramaTuru {
  /// Temassız (NFC): numara ve son kullanma; ad çoğu kartta yoktur.
  nfc,

  /// Kamera ve cihaz içi yazı tanıma; görüntü saklanmaz, gönderilmez.
  kamera,
}

sealed class TaramaOlayi {
  const TaramaOlayi();
}

/// Ekranda gösterilecek durum ("Kartı yaklaştır", "NFC kapalı"...).
class TaramaNotu extends TaramaOlayi {
  const TaramaNotu(this.mesaj, {this.hata = false, this.ayarlar = false});
  final String mesaj;
  final bool hata;

  /// Kişi telefon ayarına yönlendirilmeli (NFC kapalı, kamera izni yok).
  final bool ayarlar;
}

class TaramaOkundu extends TaramaOlayi {
  const TaramaOkundu(this.kart);
  final OkunanKart kart;
}

/// Bir okuma oturumu: ekran açılınca [baslat], kapanınca [kapat] (donanım
/// bırakılır). Olaylar ekranda gösterilir; [TaramaOkundu] gelince ekran kapanır.
abstract interface class KartTaramaOturumu {
  Stream<TaramaOlayi> get olaylar;
  Future<void> baslat();
  Future<void> kapat();

  /// Telefonun ilgili ayar ekranı (NFC ayarı, uygulama izinleri).
  Future<void> ayarlariAc();
}
