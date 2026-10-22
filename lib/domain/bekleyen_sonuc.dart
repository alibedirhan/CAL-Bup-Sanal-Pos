import 'tahsilat.dart';

/// DenizPay sonuç ekranından okunup bu cihazda bekleyen sonuç (`web/sonuc_kutusu.js`).
/// Oturum yalnız Sanal POS sekmesinde olduğundan sunucuya o sekme yazar.
/// Biçim JS tarafında da denetlenir; burada yeniden doğrulanır, bozuk kayıt `null`.
class BekleyenSonuc {
  const BekleyenSonuc._(this.kullaniciId, this.islem, this.okunma);
  final String kullaniciId;

  /// Kullanıcı adı yazılırken doldurulur; burada geçici bir addır.
  final PosIslemi islem;

  /// Sonucun DenizPay ekranından okunduğu an (telefon saati); yalnız bilgi.
  final DateTime okunma;

  static BekleyenSonuc? oku(Map<String, Object?> j, String kullaniciAd) {
    try {
      final uid = j['uid']! as String;
      return BekleyenSonuc._(
        uid,
        PosIslemi(
          posSiparisNo: j['posSiparisNo']! as String,
          kullaniciId: uid,
          kullaniciAd: kullaniciAd,
          cariId: j['cariId']! as String,
          cariAd: j['cariAd']! as String,
          kimlikNo: j['kimlikNo']! as String,
          kartSonDort: j['kartSonDort']! as String,
          girisId: j['girisId']! as String,
          sonuc: switch (j['sonuc']) {
            'basarili' => IslemSonucu.basarili,
            'hata' => IslemSonucu.hata,
            _ => throw const FormatException('sonuc'),
          },
          aciklama: j['aciklama']! as String,
          uyeSiparisNo: j['uyeSiparisNo']! as String,
          tutarMetni: j['tutarMetni']! as String,
          kaynak: IslemKaynagi.yerImi,
        ),
        DateTime.fromMillisecondsSinceEpoch(j['okunma']! as int),
      );
    } catch (_) {
      return null;
    }
  }
}
