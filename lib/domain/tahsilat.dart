import 'hata.dart';
import 'modeller.dart';

/// DenizPay sonuç ekranı: "Onay Formu" başarılı, "Hata Formu" başarısız ödemedir.
enum IslemSonucu { basarili, hata }

/// Sonuç nasıl kaydedildi. Kodlar sunucu kuralı (`firestore.rules`) ile aynıdır.
enum IslemKaynagi {
  /// Web: DenizPay sonuç ekranında "BUP Doldur" yer imiyle.
  yerImi('yer_imi', 'Sonuç ekranından'),

  /// Cari profilinden elle.
  elle('elle', 'Elle'),

  /// Android: uygulama içi DenizPay ekranının sonuç sayfasından (27 Ekim 2026).
  uygulama('uygulama', 'Uygulama içi DenizPay');

  const IslemKaynagi(this.kod, this.etiket);
  final String kod, etiket;

  static IslemKaynagi? kodla(Object? kod) {
    for (final k in values) {
      if (k.kod == kod) return k;
    }
    return null;
  }

  /// Bu kaynağın kurabileceği cari eşleşmeleri (denetim izi tutarlılığı).
  Set<CariEslesmesi> get eslesmeler => switch (this) {
    yerImi => const {
      CariEslesmesi.sonucEkrani,
      CariEslesmesi.kartSayfasi,
      CariEslesmesi.tekGiris,
      CariEslesmesi.secim,
      CariEslesmesi.sonGiris,
    },
    elle => const {CariEslesmesi.elle},
    uygulama => const {CariEslesmesi.uygulamaIci},
  };
}

/// Ödemenin hangi cariye ait olduğunun nasıl belirlendiği (denetim izi).
/// Kodlar sunucu kuralı ve `web/cari_eslestir.js` ile aynıdır.
enum CariEslesmesi {
  /// DenizPay sonuç ekranındaki firma numarası bir girişle aynı.
  sonucEkrani('sonuc_ekrani', 'Sonuç ekranındaki firma numarasıyla'),

  /// Aynı DenizPay sekmesinde kart sayfasında okunan firma numarasıyla.
  kartSayfasi('kart_sayfasi', 'Kart sayfasındaki firma numarasıyla'),

  /// Son 2 saatte bu telefonda yalnız bu cariyle giriş yapılmıştı.
  tekGiris('tek_giris', 'Telefondaki tek DenizPay girişiyle'),

  /// Birden fazla aday vardı; kaydeden kişi cariyi seçti.
  secim('secim', 'Kaydeden kişinin seçimiyle'),

  /// 0.9.0 yer imi: telefondaki son girişe bağlandı.
  sonGiris('son_giris', 'Telefondaki son DenizPay girişiyle'),

  /// Cari profilinden elle kaydedildi.
  elle('elle', 'Cari profilinden elle'),

  /// Android: DenizPay bu cari için uygulama içinde, temiz oturumla açıldı;
  /// sonuç o oturumun ekranından okundu (cari kesin bilinir).
  uygulamaIci('uygulama_ici', 'Uygulama içi DenizPay oturumuyla');

  const CariEslesmesi(this.kod, this.etiket);
  final String kod, etiket;

  static CariEslesmesi? kodla(Object? kod) {
    for (final e in values) {
      if (e.kod == kod) return e;
    }
    return null;
  }
}

final _posNo = RegExp(r'^[A-Z0-9_-]{4,64}$');
final _rakam4 = RegExp(r'^[0-9]{4}$');
final _kimlik = RegExp(r'^[0-9]{10,11}$');

/// Ekranda görünmeyen biçim işaretleri (yön, sıfır genişlik, yumuşak tire).
/// Banka sayfalarının yazısında bulunabilir; okunan değerden atılır.
/// `web/sonuc_coz.js` ve `web/sonuc_kutusu.js` aynı kümeyi kullanır.
final gorunmez = RegExp(
  r'[\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
);

/// DenizPay'in yazdığı işlem numarası; boşluklar atılır, büyük harfe çevrilir.
String posNoDuzelt(String deger) {
  final no = deger
      .replaceAll(gorunmez, '')
      .replaceAll(RegExp(r'\s'), '')
      .toUpperCase();
  if (!_posNo.hasMatch(no)) {
    throw const PosHatasi(
      'pos_no',
      'Pos Sipariş Numarasını DenizPay ekranındaki gibi yaz (ör. VP1000…).',
    );
  }
  return no;
}

/// DenizPay tutar yazısını kuruşa çevirir; emin olunamazsa `null`.
/// "4500" → 450000, "45678,90" → 4567890, "4.500" → 450000, "45.50" → 4550.
/// Virgül kuruş, nokta binlik ayracıdır; tek nokta ve 1–2 hane kuruş sayılır.
int? tutarCoz(String metin) {
  final t = metin
      .replaceAll(gorunmez, '')
      .replaceAll(RegExp(r'(TL|TRY|₺)', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\s ]'), '');
  final binlik = RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+$');
  String tam, kurus = '';
  if (RegExp(r'^[0-9.]+,[0-9]{1,2}$').hasMatch(t)) {
    final p = t.split(',');
    if (p[0].contains('.') && !binlik.hasMatch(p[0])) return null;
    tam = p[0].replaceAll('.', '');
    kurus = p[1];
  } else if (binlik.hasMatch(t)) {
    tam = t.replaceAll('.', '');
  } else if (RegExp(r'^[0-9]+\.[0-9]{1,2}$').hasMatch(t)) {
    final p = t.split('.');
    tam = p[0];
    kurus = p[1];
  } else if (RegExp(r'^[0-9]+$').hasMatch(t)) {
    tam = t;
  } else {
    return null;
  }
  if (tam.isEmpty || tam.length > 10) return null;
  return int.parse(tam) * 100 + int.parse(kurus.padRight(2, '0'));
}

/// 450000 → "4.500,00 TL".
String tutarYaz(int kurus) {
  final tl = (kurus ~/ 100).toString();
  final gruplu = tl.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$gruplu,${(kurus % 100).toString().padLeft(2, '0')} TL';
}

/// Türkiye saati: 2016'dan beri yıl boyu UTC+3 (yaz saati yok). Gün sonu
/// cihazın saat dilimine değil bu saate göre 00:00'da kapanır.
class Gun implements Comparable<Gun> {
  const Gun(this.yil, this.ay, this.gun);
  static const fark = Duration(hours: 3);

  /// Verilen anın Türkiye takvimindeki günü.
  factory Gun.ani(DateTime an) {
    final y = an.toUtc().add(fark);
    return Gun(y.year, y.month, y.day);
  }
  final int yil, ay, gun;

  /// Bu günün başladığı an (UTC); bitiş ertesi günün başlangıcıdır.
  DateTime get baslangic => DateTime.utc(yil, ay, gun).subtract(fark);
  DateTime get bitis => sonraki.baslangic;
  Gun get onceki => Gun.ani(baslangic.subtract(const Duration(hours: 12)));
  Gun get sonraki => Gun.ani(baslangic.add(const Duration(hours: 36)));
  String get etiket => '${_iki(gun)}.${_iki(ay)}.$yil'; // 22.10.2026
  String get anahtar => '$yil-${_iki(ay)}-${_iki(gun)}';
  bool kapandi(DateTime simdi) => !simdi.isBefore(bitis);
  @override
  int compareTo(Gun o) => baslangic.compareTo(o.baslangic);
  @override
  bool operator ==(Object other) =>
      other is Gun && other.yil == yil && other.ay == ay && other.gun == gun;
  @override
  int get hashCode => Object.hash(yil, ay, gun);
}

String _iki(int v) => v.toString().padLeft(2, '0');

/// Bir anın Türkiye saatiyle "10:48" gösterimi.
String saatYaz(DateTime an) {
  final y = an.toUtc().add(Gun.fark);
  return '${_iki(y.hour)}:${_iki(y.minute)}';
}

/// Bir anın Türkiye saatiyle "22.10.2026 10:48" gösterimi.
String tarihSaatYaz(DateTime an) => '${Gun.ani(an).etiket} ${saatYaz(an)}';

/// "DenizPay'e giriş yap"a basıldığı an. Sonucu kaydedilmemiş girişler gün
/// sonunda uyarı olarak görünür. Kart bilgisi yalnız son dört hanedir.
class PosGirisi {
  PosGirisi({
    required this.id,
    required this.kullaniciId,
    required String kullaniciAd,
    required this.cariId,
    required String cariAd,
    required this.kimlikNo,
    this.kartSonDort = '',
    this.zaman,
  }) : kullaniciAd = duzMetin(kullaniciAd, enAz: 2, enFazla: 80),
       cariAd = duzMetin(cariAd, enAz: 2, enFazla: 80) {
    if (!RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id) ||
        kullaniciId.isEmpty ||
        cariId.isEmpty ||
        !_kimlik.hasMatch(kimlikNo) ||
        (kartSonDort.isNotEmpty && !_rakam4.hasMatch(kartSonDort))) {
      throw const PosHatasi('giris', 'Giriş kaydı hazırlanamadı.');
    }
  }
  final String id, kullaniciId, kullaniciAd, cariId, cariAd, kimlikNo;
  final String kartSonDort;

  /// Sunucu saati; yazılmadan önce `null`.
  final DateTime? zaman;
}

/// DenizPay'in sonuç ekranındaki bir ödeme denemesi. Kayıt değiştirilemez
/// ve silinemez; gün bitince o günün gün sonu kendiliğinden kesinleşir.
class PosIslemi {
  PosIslemi({
    required String posSiparisNo,
    required this.kullaniciId,
    required String kullaniciAd,
    required this.cariId,
    required String cariAd,
    required this.kimlikNo,
    required this.sonuc,
    required String aciklama,
    required String tutarMetni,
    required this.kaynak,
    required this.eslesme,
    this.kartSonDort = '',
    this.girisId = '',
    String uyeSiparisNo = '',
    this.okunma,
    this.zaman,
  }) : posSiparisNo = posNoDuzelt(posSiparisNo),
       kullaniciAd = duzMetin(kullaniciAd, enAz: 2, enFazla: 80),
       cariAd = duzMetin(cariAd, enAz: 2, enFazla: 80),
       aciklama = duzMetin(aciklama, enFazla: 200),
       tutarMetni = duzMetin(tutarMetni, enFazla: 40),
       uyeSiparisNo = uyeSiparisNo.trim().isEmpty
           ? ''
           : duzMetin(uyeSiparisNo, enFazla: 40),
       tutarKurus = tutarCoz(tutarMetni) {
    if (kullaniciId.isEmpty ||
        cariId.isEmpty ||
        !_kimlik.hasMatch(kimlikNo) ||
        (kartSonDort.isNotEmpty && !_rakam4.hasMatch(kartSonDort)) ||
        (girisId.isNotEmpty &&
            !RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(girisId)) ||
        // Elle kayıt cariyi profilden alır; yer imi ve uygulama kaydı ekrandan
        // okunur (okunma anı vardır; 0.9.0 yer imi kayıtlarında yoktu).
        !kaynak.eslesmeler.contains(eslesme) ||
        (kaynak == IslemKaynagi.elle && okunma != null) ||
        (kaynak == IslemKaynagi.uygulama && okunma == null)) {
      throw const PosHatasi('islem', 'İşlem kaydı hazırlanamadı.');
    }
  }
  final String posSiparisNo, kullaniciId, kullaniciAd, cariId, cariAd;
  final String kimlikNo, aciklama, tutarMetni, uyeSiparisNo;
  final String kartSonDort, girisId;
  final IslemSonucu sonuc;
  final IslemKaynagi kaynak;
  final CariEslesmesi eslesme;

  /// Sonucun DenizPay ekranından okunduğu an (telefon saati, yalnız bilgi);
  /// elle kayıtta yoktur. Gün ve sıra her zaman sunucu saatiyle ([zaman]).
  final DateTime? okunma;

  /// Tutar yazısı okunamazsa `null`; o işlem toplamda ayrıca uyarılır.
  final int? tutarKurus;
  final DateTime? zaman;
  bool get basarili => sonuc == IslemSonucu.basarili;

  /// Sunucudaki belge kimliği, bkz. [belgeKimligi].
  String get kimlik => belgeKimligi(posSiparisNo, sonuc);

  /// Sonuç, kaydedildiği andan belirgin biçimde önce okunduysa (Sanal POS
  /// sekmesine geç dönüldü) okunma anı; gün sonunda ayrıca gösterilir.
  DateTime? get gecOkunma {
    final o = okunma, z = zaman;
    if (o == null || z == null) return null;
    return z.difference(o) > const Duration(minutes: 10) ? o : null;
  }
}

/// Bir ödeme denemesinin kimliği: başarılıda Pos Sipariş Numarası, başarısızda
/// sonuna "-h" eklenmiş hali (numara büyük harf olduğu için karışmaz). DenizPay
/// başarısız denemeden sonraki başarılı ödemeye aynı numarayı verse de ikisi
/// ayrı kaydedilir; aynı sonucun ikinci kez yazılması yine engellenir.
/// `web/sonuc_kutusu.js` ve `firestore.rules` aynı kuralı uygular.
String belgeKimligi(String posSiparisNo, IslemSonucu sonuc) =>
    sonuc == IslemSonucu.hata ? '$posSiparisNo-h' : posSiparisNo;

/// Aynı ödeme mi: aynı kimlik, cari ve tutar. Aynı kimlikte farklı cari veya
/// tutar sessizce "kayıtlı" sayılmaz.
bool ayniOdeme(PosIslemi a, PosIslemi b) =>
    a.kimlik == b.kimlik &&
    a.cariId == b.cariId &&
    (a.tutarKurus != null && b.tutarKurus != null
        ? a.tutarKurus == b.tutarKurus
        : a.tutarMetni == b.tutarMetni);

/// Kaydın sonucu: yeni yazıldı mı, aynı kimlikte kayıt zaten var mıydı.
/// [farkli]: var olan kayıt istenenle aynı ödeme değil (cari veya tutar farklı).
class IslemKaydi {
  const IslemKaydi(this.islem, {required this.zatenVardi, this.farkli = false});
  final PosIslemi islem;
  final bool zatenVardi, farkli;
}
