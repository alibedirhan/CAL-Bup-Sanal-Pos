import 'hata.dart';

String duzMetin(String deger, {int enAz = 1, int enFazla = 100}) {
  final metin = deger.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (metin.length < enAz ||
      metin.length > enFazla ||
      RegExp(
        r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u206F]',
      ).hasMatch(deger)) {
    throw const PosHatasi(
      'metin',
      'Alanı geçerli uzunlukta, düz metin olarak yazın.',
    );
  }
  return metin;
}

/// Türkçe ve klavyesi Türkçe olmayan kullanıcılar için arama anahtarı.
String aramaAnahtari(String deger) => deger
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .replaceAll('ı', 'i')
    .toLowerCase()
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .trim();

class Cari {
  Cari({
    required this.id,
    required this.sahipId,
    required String ad,
    required String kod,
    this.yildizli = false,
    this.surum = 1,
    this.kimlikNo = '',
  }) : ad = duzMetin(ad, enAz: 2, enFazla: 80),
       kod = duzMetin(kod, enFazla: 24) {
    if (id.isEmpty ||
        sahipId.isEmpty ||
        surum < 1 ||
        (kimlikNo.isNotEmpty &&
            !RegExp(r'^[0-9]{10,11}$').hasMatch(kimlikNo)) ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(this.kod)) {
      throw const PosHatasi('cari', 'Cari kodunda harf, rakam, tire kullanın.');
    }
  }
  final String id, sahipId, ad, kod;
  final String kimlikNo;
  final bool yildizli;
  final int surum;

  Cari duzenle({String? ad, String? kod, bool? yildizli, String? kimlikNo}) =>
      Cari(
        id: id,
        sahipId: sahipId,
        ad: ad ?? this.ad,
        kod: kod ?? this.kod,
        yildizli: yildizli ?? this.yildizli,
        surum: surum + 1,
        kimlikNo: kimlikNo ?? this.kimlikNo,
      );
  bool eslesir(String aranan) {
    final anahtar = aramaAnahtari(aranan);
    return aramaAnahtari(ad).contains(anahtar) || kimlikNo.contains(anahtar);
  }
}

/// Yalnız gösterim özeti. Tam kart numarası, CVV ve sağlayıcı sırrı içermez.
/// Canlı sağlayıcı referansı gelecekte sunucudaki adaptörde kalacaktır.
class KartOzeti {
  KartOzeti({
    required this.id,
    required this.cariId,
    required String ad,
    required this.sonDort,
    required this.ay,
    required this.yil,
    this.cihazKayitId,
  }) : ad = duzMetin(ad, enAz: 2, enFazla: 60) {
    if (id.isEmpty ||
        cariId.isEmpty ||
        !RegExp(r'^\d{4}$').hasMatch(sonDort) ||
        ay < 1 ||
        ay > 12 ||
        yil < 2000 ||
        yil > 2199 ||
        (cihazKayitId != null &&
            !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(cihazKayitId!))) {
      throw const PosHatasi(
        'kart',
        'Kart özeti veya son kullanma tarihi geçersiz.',
      );
    }
  }
  final String id, cariId, ad, sonDort;
  final String? cihazKayitId;
  KartOzeti cihazKaydiyla(String kayitId) => KartOzeti(
    id: id,
    cariId: cariId,
    ad: ad,
    sonDort: sonDort,
    ay: ay,
    yil: yil,
    cihazKayitId: kayitId,
  );
  final int ay, yil;
  String get maske => '••••  $sonDort';
  String get tarih => '${ay.toString().padLeft(2, '0')} / $yil';
  bool suresiGecti(DateTime simdi) =>
      yil < simdi.year || (yil == simdi.year && ay < simdi.month);
}

class CariOzeti {
  const CariOzeti(this.cari, this.kartSayisi);
  final Cari cari;
  final int kartSayisi;
}

class CariProfili {
  CariProfili(this.cari, Iterable<KartOzeti> kartlar)
    : kartlar = List.unmodifiable(kartlar);
  final Cari cari;
  final List<KartOzeti> kartlar;
}

/// `kartId` yoksa kartsız geçiştir: yalnız cari doğrulanır, kart doldurulmaz.
class PosSecimi {
  const PosSecimi({
    required this.cariId,
    required this.cariSurumu,
    required this.kartId,
  });
  final String cariId;
  final String? kartId;
  final int cariSurumu;
}

/// Ödeme sonucu değildir; yalnız güncel seçimin doğrulandığını gösterir.
/// `kimlikNo` ve `zaman` servis tarafından sunucudan okunan kayıttan yazılır.
class DenemeSonucu {
  const DenemeSonucu(
    this.cariAdi,
    this.kartSonDort, {
    this.kimlikNo = '',
    this.zaman,
    this.kart,
  });
  final String cariAdi, kartSonDort, kimlikNo;
  final DateTime? zaman;

  /// Sunucudan yeniden okunan kart özeti; kartsız geçişte yoktur.
  final KartOzeti? kart;
}
