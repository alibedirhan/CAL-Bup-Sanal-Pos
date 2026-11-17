/// Gizli "Konum kurulumu" ekranının gösterdiği terminal durumu (docs/ROTA_MIMARI.md M16).
/// Saf: Android kanalından gelen haritayı güvenli biçimde okur.
class RotaKurulumDurumu {
  const RotaKurulumDurumu({
    required this.etkin,
    required this.kod,
    required this.konumIzni,
    required this.arkaPlanIzni,
    required this.pilMuaf,
    required this.konumAcik,
    required this.hizmet,
    required this.onayli,
    required this.takip,
    required this.bekleyen,
  });

  factory RotaKurulumDurumu.haritadan(Map<Object?, Object?> m) {
    bool b(String k) => m[k] == true;
    final kod = m['kod'];
    final bekleyen = m['bekleyen'];
    return RotaKurulumDurumu(
      etkin: b('etkin'),
      kod: kod is String && RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(kod)
          ? kod
          : null,
      konumIzni: b('konumIzni'),
      arkaPlanIzni: b('arkaPlanIzni'),
      pilMuaf: b('pilMuaf'),
      konumAcik: b('konumAcik'),
      hizmet: b('hizmet'),
      onayli: b('onayli'),
      takip: b('takip'),
      bekleyen: bekleyen is int && bekleyen >= 0 ? bekleyen : 0,
    );
  }

  /// Yapılandırma yok (deneme derlemesi): rota bu uygulamada kapalı.
  final bool etkin;

  /// Terminal kodu: CAL_bup'taki onay listesinde bu kod görünür. Hizmet bir kez
  /// çalışıp kimlik alınana kadar yoktur.
  final String? kod;
  final bool konumIzni, arkaPlanIzni, pilMuaf, konumAcik, hizmet;

  /// Merkezin son bilinen kararı (terminalde saklanan).
  final bool onayli, takip;

  /// Gönderilmeyi bekleyen kayıt sayısı.
  final int bekleyen;

  /// Kurulumun tamamlanması için terminalde yapılacak bir şey kalmadı mı.
  bool get terminalHazir =>
      etkin && konumIzni && arkaPlanIzni && pilMuaf && konumAcik && hizmet;
}
