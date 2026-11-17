import '../domain/rota_kurulumu.dart';

/// Terminalde konum kurulumu (Android, docs/ROTA_MIMARI.md M16). Yalnız izin ve
/// hizmet içindir; rota ayarları ve konum verisi bu porttan görülmez/değişmez.
abstract interface class RotaKurulumPortu {
  Future<RotaKurulumDurumu> durum();

  /// Konum izni penceresi. Döner: verildi mi.
  Future<bool> konumIzni();

  /// "Her zaman izin ver" (arka plan konumu); önce konum izni gerekir.
  Future<bool> arkaPlanIzni();

  /// Pil iyileştirmesinden muafiyet penceresi.
  Future<void> pilMuafiyeti();

  /// Telefonun konum ayarı (konum kapalıysa).
  Future<void> konumAyari();

  /// Hizmeti başlatır (izin varsa). Döner: başladı mı.
  Future<bool> baslat();
}
