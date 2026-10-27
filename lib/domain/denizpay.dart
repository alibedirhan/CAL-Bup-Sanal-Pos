import 'tahsilat.dart';

/// Uygulama içi DenizPay (Android, docs/ANDROID_PLANI.md §3): adres kuralları
/// ve sonuç ekranının okunması. Saf kurallar; Flutter/WebView bilmez.

/// Bir gezinme isteği için karar.
enum Gezinme {
  /// DenizPay'in kendi sayfası: okunur, kart yalnız burada doldurulur.
  denizPay,

  /// Başka güvenli site (3D Secure / banka): açılır, hiçbir betik eklenmez.
  disSite,

  /// http, intent:, javascript:, file:, data: … açılmaz.
  engel,
}

/// DenizPay kökeni ve gezinme kuralı. Canlıda yalnız
/// `https://denizpay.bupilic.com.tr`; yalnız emülatör testlerinde taklit köken
/// (bilgisayarın yerel adresi) verilir, o zaman aynı ana makinedeki http taklit
/// banka sayfası da açılabilir. Canlı kökende http hiçbir zaman açılmaz.
class DenizPayAdresi {
  DenizPayAdresi(this.koken)
    : assert(koken.path.isEmpty || koken.path == '/', 'yalnız köken');
  static final canli = DenizPayAdresi(
    Uri.parse('https://denizpay.bupilic.com.tr'),
  );
  final Uri koken;

  Uri get giris => koken.replace(path: '/login.aspx');

  bool denizPayMi(Uri u) =>
      u.scheme == koken.scheme && u.host == koken.host && u.port == koken.port;

  Gezinme karar(Uri u) {
    if (denizPayMi(u)) return Gezinme.denizPay;
    if (u.scheme == 'about' && u.path == 'blank') return Gezinme.disSite;
    final taklitBanka =
        koken.scheme == 'http' && u.scheme == 'http' && u.host == koken.host;
    if ((u.scheme == 'https' || taklitBanka) &&
        u.host.isNotEmpty &&
        u.userInfo.isEmpty) {
      return Gezinme.disSite;
    }
    return Gezinme.engel;
  }
}

/// DenizPay sayfasından okunan özet: görünen yazı (en çok 5000), etiketli
/// kutular ([etiket, değer], en çok 40; kart numarasına benzeyenler atılmış) ve
/// sayfadaki "Firma İsmi : … (VKN)" numarası. Biçimi `web/sonuc_coz.js`
/// `sayfaGecerli` ile aynıdır (Android'de yer imi sekme notu yoktur).
class SayfaOzeti {
  const SayfaOzeti({
    required this.metin,
    required this.alanlar,
    required this.firma,
    required this.kartAlanlari,
  });
  final String metin;
  final List<(String, String)> alanlar;
  final String? firma;

  /// Kart numarası ve son kullanma kutuları tek ve görünür (kart sayfası).
  final bool kartAlanlari;

  /// Sayfa betiğinin döndürdüğü JSON; biçim dışıysa `null` (hiçbir şey yapılmaz).
  static SayfaOzeti? oku(Object? d) {
    if (d is! Map ||
        d.length != 4 ||
        d['metin'] is! String ||
        (d['metin'] as String).length > 5000 ||
        d['alanlar'] is! List ||
        (d['alanlar'] as List).length > 40 ||
        d['kartAlanlari'] is! bool) {
      return null;
    }
    final firma = d['firma'];
    if (firma != null &&
        (firma is! String || !RegExp(r'^[0-9]{10,11}$').hasMatch(firma))) {
      return null;
    }
    final alanlar = <(String, String)>[];
    for (final a in d['alanlar'] as List) {
      if (a is! List ||
          a.length != 2 ||
          a[0] is! String ||
          (a[0] as String).length > 80 ||
          a[1] is! String ||
          (a[1] as String).length > 200) {
        return null;
      }
      alanlar.add((a[0] as String, a[1] as String));
    }
    return SayfaOzeti(
      metin: d['metin'] as String,
      alanlar: alanlar,
      firma: firma as String?,
      kartAlanlari: d['kartAlanlari'] as bool,
    );
  }
}

/// Sonuç ekranından okunan ödeme denemesi.
class OkunanSonuc {
  const OkunanSonuc({
    required this.sonuc,
    required this.aciklama,
    required this.posSiparisNo,
    required this.uyeSiparisNo,
    required this.tutarMetni,
  });
  final IslemSonucu sonuc;
  final String aciklama, posSiparisNo, uyeSiparisNo, tutarMetni;
  int? get tutarKurus => tutarCoz(tutarMetni);
}

/// Okuma sonucu: [sonuc] ya da kişiye gösterilecek [hata].
typedef SonucOkumasi = ({OkunanSonuc? sonuc, String? hata});

/// `web/sonuc_coz.js` `sonucCoz`'un Dart karşılığı; ikisi
/// `test/veri/tahsilat_ornekleri.json` örnekleriyle birebir sınanır.
/// Önce etiketli kutular; kutu yoksa sayfa yazısı (etiket + alt satır, aynı
/// satırda "Etiket: değer" veya sekmeyle ayrılmış tablo). Belirsizse okumaz.
SonucOkumasi sonucCoz(SayfaOzeti s) {
  SonucOkumasi hata(String m) => (sonuc: null, hata: m);
  final metin = _anahtar(s.metin);
  final onay = RegExp(r'\bonay formu\b').hasMatch(metin);
  final hataFormu = RegExp(r'\bhata formu\b').hasMatch(metin);
  if (onay == hataFormu) {
    return hata(
      'Bu sayfa DenizPay sonuç ekranı (Onay Formu / Hata Formu) değil. Ödeme bitince sonuç ekranında dokun.',
    );
  }
  final aciklama = _alan(s, _Etiket.aciklama);
  final pos = _duz(
    _alan(s, _Etiket.pos),
  ).replaceAll(RegExp(r'\s'), '').toUpperCase();
  final tutarMetni = _alan(s, _Etiket.tutar);
  final uye = onay ? _alan(s, _Etiket.uye) ?? '' : '';
  if (!RegExp(r'^[A-Z0-9_-]{4,64}$').hasMatch(pos)) {
    return hata('Pos Sipariş Numarası okunamadı. Sonucu elle kaydet.');
  }
  if (tutarMetni == null ||
      tutarMetni.isEmpty ||
      tutarMetni.length > 40 ||
      _kontrol.hasMatch(tutarMetni) ||
      !RegExp(r'[0-9]').hasMatch(tutarMetni)) {
    return hata('Tutar okunamadı. Sonucu elle kaydet.');
  }
  if (aciklama == null ||
      aciklama.isEmpty ||
      aciklama.length > 200 ||
      _kontrol.hasMatch(aciklama)) {
    return hata('Açıklama okunamadı. Sonucu elle kaydet.');
  }
  if (uye.length > 40) {
    return hata('Üye Sipariş Numarası okunamadı. Sonucu elle kaydet.');
  }
  // "Onay Formu" yalnız açıklama da başarıyı söylüyorsa başarılı sayılır.
  if (onay && !RegExp('basari').hasMatch(_anahtar(aciklama))) {
    final kisa = aciklama.length > 80 ? aciklama.substring(0, 80) : aciklama;
    return hata(
      'Ödeme sonucu anlaşılamadı ($kisa). DenizPay’de kontrol edip elle kaydet.',
    );
  }
  return (
    sonuc: OkunanSonuc(
      sonuc: onay ? IslemSonucu.basarili : IslemSonucu.hata,
      aciklama: aciklama,
      posSiparisNo: pos,
      uyeSiparisNo: uye,
      tutarMetni: tutarMetni,
    ),
    hata: null,
  );
}

abstract final class _Etiket {
  static const aciklama = 'aciklama',
      uye = 'uye siparis numarasi',
      pos = 'pos siparis numarasi',
      tutar = 'tutar';
  static const hepsi = {aciklama, uye, pos, tutar};
}

final _kontrol = RegExp(r'[\x00-\x1f\x7f]');

String _duz(String? v) =>
    (v ?? '').replaceAll(gorunmez, '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Türkçe büyük/küçük harf ve klavye farkını yok sayan karşılaştırma anahtarı.
String _anahtar(String? v) => _duz(v)
    .replaceAll(RegExp('[İIı]'), 'i')
    .toLowerCase()
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[\s:*]+$'), '');

/// "Etiket: değer" ya da tablo hücreleri (etiket, sekme, değer) tek satırda.
(String, String)? _ayniSatir(String satir) {
  final m = RegExp(r'^([^:\t]{1,80}?)\s*(?::|\t)\s*(\S.*)$').firstMatch(satir);
  return m == null ? null : (_anahtar(m[1]), _duz(m[2]));
}

String? _alan(SayfaOzeti s, String etiket) {
  final bulunan = [
    for (final (e, d) in s.alanlar)
      if (_anahtar(e) == etiket) _duz(d),
  ].where((d) => d.isNotEmpty).toList();
  if (bulunan.length == 1) return bulunan.single;
  if (bulunan.length > 1) return null;
  final satirlar = s.metin
      .split(RegExp(r'\r?\n'))
      .where((x) => _duz(x).isNotEmpty)
      .toList();
  final aday = <String?>[];
  for (var i = 0; i < satirlar.length; i++) {
    final x = satirlar[i];
    if (_anahtar(x) == etiket) {
      final sonraki = i + 1 < satirlar.length ? satirlar[i + 1] : null;
      final ad = sonraki == null ? '' : _anahtar(sonraki);
      aday.add(
        ad.isNotEmpty &&
                !_Etiket.hepsi.contains(ad) &&
                !_Etiket.hepsi.contains(_ayniSatir(sonraki!)?.$1)
            ? _duz(sonraki)
            : null,
      );
      continue;
    }
    final a = _ayniSatir(x);
    if (a != null && a.$1 == etiket) aday.add(a.$2);
  }
  return aday.length == 1 ? aday.single : null;
}
