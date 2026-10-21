import 'kart_bilgileri.dart';

/// Karttan okunan (telefonun kart tarayıcısı, Canlı Metin/OCR veya yapıştırma)
/// metinden yalnız emin olunan alanlar çıkarılır. Belirsizlikte alan boş kalır;
/// tahmin edilmez. CVV hiçbir zaman çıkarılmaz. Metin saklanmaz.
class OkunanKart {
  const OkunanKart({this.numara, this.ay, this.yil, this.ad});
  final String? numara, ad;
  final int? ay, yil;
  bool get bos => numara == null && ay == null && ad == null;
}

/// İki haneli yıl 20xx sayılır ("31" → 2031). 2000–2199 dışı veya bozuk: null.
int? sktYili(String deger) {
  final d = deger.trim();
  if (!RegExp(r'^([0-9]{2}|[0-9]{4})$').hasMatch(d)) return null;
  final y = d.length == 2 ? 2000 + int.parse(d) : int.parse(d);
  return y >= 2000 && y <= 2199 ? y : null;
}

/// "07/31", "07 / 2031", "7-31", "07.31" → (7, 2031). Tek kutuya gelen tarih için.
({int ay, int yil})? sktCoz(String deger) {
  final m = RegExp(
    r'^\s*([0-9]{1,2})\s*[/.\-]\s*([0-9]{2}|[0-9]{4})\s*$',
  ).firstMatch(deger);
  if (m == null) return null;
  final ay = int.parse(m[1]!), yil = sktYili(m[2]!);
  return ay >= 1 && ay <= 12 && yil != null ? (ay: ay, yil: yil) : null;
}

// OCR'nin rakam yerine okuyabildiği harfler; yalnız rakam gruplarının içinde çevrilir.
const _benzer = {
  'O': '0',
  'o': '0',
  'D': '0',
  'Q': '0',
  'I': '1',
  'l': '1',
  '|': '1',
  'i': '1',
  'S': '5',
  's': '5',
  'B': '8',
  'Z': '2',
};
final _numaraAday = RegExp(
  r'[0-9OoDQIl|iSsBZ][0-9OoDQIl|iSsBZ \-]{10,26}[0-9]',
);
final _tarihAday = RegExp(
  r'(?<![0-9])(0?[1-9]|1[0-2])\s*[/\-.]\s*([0-9]{4}|[0-9]{2})(?![0-9])',
);
final _tarihEtiketi = RegExp(
  r'THRU|SKT|S\.K\.T|SON\s*KUL|EXP|GE[ÇC]ERL[İI]|VALID\s*(UNTIL|TO)|GOOD',
  caseSensitive: false,
);
final _baslangicEtiketi = RegExp(
  r'FROM|MEMBER\s*SINCE|BA[ŞS]LANGI[ÇC]',
  caseSensitive: false,
);
// Kart yüzünde ad olmayan sözcükler: banka, marka, ürün ve etiketler.
const _adOlmayan = {
  'BANK',
  'BANKASI',
  'BANKA',
  'BANKKART',
  'KART',
  'KARTI',
  'CARD',
  'CREDIT',
  'KREDI',
  'DEBIT',
  'BANKAMATIK',
  'VISA',
  'MASTERCARD',
  'MASTER',
  'MAESTRO',
  'TROY',
  'AMEX',
  'AMERICAN',
  'EXPRESS',
  'VALID',
  'THRU',
  'FROM',
  'GOOD',
  'MONTH',
  'YEAR',
  'EXPIRES',
  'EXP',
  'SKT',
  'SON',
  'KULLANMA',
  'TARIHI',
  'PLATINUM',
  'GOLD',
  'CLASSIC',
  'WORLD',
  'ELITE',
  'PREMIUM',
  'SIGNATURE',
  'INFINITE',
  'BUSINESS',
  'TICARI',
  'BONUS',
  'AXESS',
  'MAXIMUM',
  'PARAF',
  'CARDFINANS',
  'WINGS',
  'MILES',
  'SMILES',
  'ADVANTAGE',
  'ZIRAAT',
  'GARANTI',
  'AKBANK',
  'YAPI',
  'HALKBANK',
  'VAKIF',
  'VAKIFBANK',
  'QNB',
  'FINANSBANK',
  'DENIZBANK',
  'TEB',
  'ING',
  'HSBC',
  'ENPARA',
  'PAPARA',
  'ELECTRONIC',
  'ONLINE',
  'CONTACTLESS',
  'CUSTOMER',
  'MEMBER',
  'SINCE',
  'PAYPASS',
  'SECURE',
  'CHIP',
  'CVV',
  'CVC',
  'NUMBER',
  'NO',
  'SAHIBI',
  'UZERINDEKI',
  'AD',
  'SOYAD',
  'NAME',
  'HOLDER',
  'TURKIYE',
  'TURKEY',
  'PARA',
  'PREPAID',
  'GIFT',
  'VIRTUAL',
};

String _harfAnahtari(String s) => s
    .replaceAll('İ', 'I')
    .replaceAll('ı', 'I')
    .replaceAll('i', 'I')
    .toUpperCase()
    .replaceAll('Ş', 'S')
    .replaceAll('Ğ', 'G')
    .replaceAll('Ü', 'U')
    .replaceAll('Ö', 'O')
    .replaceAll('Ç', 'C');

String? _gecerliNumara(String aday) {
  if (RegExp(r'[0-9]').allMatches(aday).length < 8) return null;
  final cevrilmis = aday.split('').map((c) => _benzer[c] ?? c).join();
  final rakam = cevrilmis.replaceAll(RegExp(r'[ \-]'), '');
  if (!RegExp(r'^[0-9]{13,19}$').hasMatch(rakam)) return null;
  try {
    return kartNumarasi(rakam);
  } catch (_) {
    return null;
  }
}

OkunanKart kartMetniniOku(String metin, {required DateTime simdi}) {
  if (metin.length > 4000) return const OkunanKart();
  final satirlar = metin
      .split(RegExp(r'[\r\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Kart numarası: satır içinde veya iki satıra bölünmüş; tek ve Luhn'dan geçen.
  final numaralar = <String>{};
  var numaraSatiri = -1;
  for (final (i, s) in satirlar.indexed) {
    for (final m in _numaraAday.allMatches(s)) {
      final n = _gecerliNumara(m[0]!);
      if (n != null && numaralar.add(n) && numaraSatiri < 0) numaraSatiri = i;
    }
  }
  if (numaralar.isEmpty) {
    for (var i = 0; i + 1 < satirlar.length; i++) {
      final n = _gecerliNumara('${satirlar[i]} ${satirlar[i + 1]}');
      if (n != null && numaralar.add(n) && numaraSatiri < 0) {
        numaraSatiri = i + 1;
      }
    }
  }
  final numara = numaralar.length == 1 ? numaralar.single : null;

  // Son kullanma: etiketli tarih öncelikli; yoksa başlangıç olmayanların en geçi.
  final tarihler = <({int ay, int yil, int puan})>[];
  for (final (i, s) in satirlar.indexed) {
    final temiz = s.replaceAll(
      RegExp(r'[0-9OoIl|SB][0-9OoIl|SB \-]{10,26}[0-9]'),
      ' ',
    );
    for (final m in _tarihAday.allMatches(temiz)) {
      final ay = int.parse(m[1]!), yil = sktYili(m[2]!);
      if (yil == null || yil < simdi.year - 1 || yil > simdi.year + 20) {
        continue;
      }
      final once = temiz.substring(0, m.start);
      final onceki = i > 0 ? satirlar[i - 1] : '';
      final puan =
          _tarihEtiketi.hasMatch(once) || _tarihEtiketi.hasMatch(onceki)
          ? 2
          : _baslangicEtiketi.hasMatch(once)
          ? -1
          : 0;
      tarihler.add((ay: ay, yil: yil, puan: puan));
    }
  }
  int? ay, yil;
  final etiketli = tarihler.where((t) => t.puan == 2).toSet();
  final aday = etiketli.isNotEmpty
      ? etiketli
      : tarihler.where((t) => t.puan == 0).toSet();
  final farkli = {for (final t in aday) (t.ay, t.yil)};
  if (farkli.length == 1 || (etiketli.isEmpty && farkli.length == 2)) {
    // İki etiketsiz tarih çoğunlukla "geçerlilik başlangıcı / bitişi"dir: geç olan.
    final secilen = farkli.reduce(
      (a, b) => a.$2 * 12 + a.$1 >= b.$2 * 12 + b.$1 ? a : b,
    );
    ay = secilen.$1;
    yil = secilen.$2;
  }

  // Ad: yalnız harf, 2–4 sözcük, banka/marka/etiket sözcüğü yok; tek aday.
  final adlar = <String>[];
  for (final (i, s) in satirlar.indexed) {
    if (i == numaraSatiri) continue;
    final sozcukler = s.split(RegExp(r'\s+'));
    if (sozcukler.length < 2 || sozcukler.length > 4 || s.length > 40) continue;
    if (!RegExp(r"^[A-Za-zÇĞİÖŞÜçğıöşü.'\- ]+$").hasMatch(s)) continue;
    // Kartlarda ad büyük harfle basılıdır; küçük harfli satır başka yazıdır.
    if (s != s.toUpperCase()) continue;
    final anahtar = sozcukler
        .map(_harfAnahtari)
        .map((w) => w.replaceAll('.', ''));
    if (anahtar.any((w) => w.isEmpty || _adOlmayan.contains(w))) continue;
    if (anahtar.where((w) => w.length >= 2).length < 2) continue;
    adlar.add(s.replaceAll(RegExp(r'\s+'), ' '));
  }
  final ad = adlar.toSet().length == 1 ? adlar.first : null;
  return OkunanKart(numara: numara, ay: ay, yil: yil, ad: ad);
}
