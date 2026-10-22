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

  /// Yer iminin kurabileceği eşleşmeler; elle kayıt buradan gelmez.
  static const _yerImi = {
    CariEslesmesi.sonucEkrani,
    CariEslesmesi.kartSayfasi,
    CariEslesmesi.tekGiris,
    CariEslesmesi.secim,
  };

  static BekleyenSonuc? oku(Map<String, Object?> j, String kullaniciAd) {
    try {
      final uid = j['uid']! as String;
      final okunma = DateTime.fromMillisecondsSinceEpoch(j['okunma']! as int);
      // 1: 0.9.0 sonuç sayfası (cari = telefondaki son giriş); 2: eşleşmeli.
      final eslesme = switch (j['v']) {
        1 when !j.containsKey('eslesme') => CariEslesmesi.sonGiris,
        2 => CariEslesmesi.kodla(j['eslesme']),
        _ => null,
      };
      if (eslesme == null || (j['v'] == 2 && !_yerImi.contains(eslesme))) {
        return null;
      }
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
          eslesme: eslesme,
          okunma: okunma,
        ),
        okunma,
      );
    } catch (_) {
      return null;
    }
  }
}
