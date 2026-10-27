import 'dart:typed_data';
import 'kart_bilgileri.dart';
import 'kart_okuma.dart';

/// Temassız (NFC) banka kartından yalnız kart numarası, son kullanma ve —
/// varsa — kart üzerindeki ad okunur (EMV, ISO 7816-4). Ödeme yapılmaz:
/// kriptogram, PIN, işlem kaydı veya CVV istenmez; ödeme uygulaması seçilir,
/// "işlemi başlat" (GPO) ile kayıt yerleri öğrenilip yalnız kayıtlar okunur.
/// Kart komutları [gonder] ile iletilir (Android IsoDep). Okunan bayt dizileri
/// saklanmaz, günlüğe yazılmaz.
typedef ApduGonder = Future<Uint8List> Function(Uint8List komut);

class EmvHatasi implements Exception {
  const EmvHatasi(this.kod);

  /// 'uygulama_yok' (ödeme uygulaması bulunamadı), 'veri_yok' (numara
  /// verilmedi), 'yanit' (beklenmeyen yanıt).
  final String kod;
  @override
  String toString() => 'EmvHatasi($kod)';
}

/// Türkiye'deki yaygın kart uygulamaları; PPSE dizini yoksa sırayla denenir.
const _bilinenUygulamalar = [
  'A0000000031010', // Visa
  'A0000000041010', // Mastercard
  'A0000000043060', // Maestro
  'A0000006723010', // Troy
  'A0000006723020', // Troy (debit)
  'A00000002501', // American Express
];

Future<OkunanKart> emvKartOku(
  ApduGonder gonder, {
  required DateTime simdi,
}) async {
  final aidler = await _dizin(gonder);
  for (final aid in {...aidler, ..._bilinenUygulamalar}) {
    final fci = await _komut(gonder, _secim(aid));
    if (fci == null) continue;
    final pdol = tlvBul(fci, 0x9F38);
    final gpo = await _komut(
      gonder,
      _gpo(pdol == null ? Uint8List(0) : pdolDoldur(pdol, simdi)),
    );
    if (gpo == null) continue;
    final bulunan = <int, Uint8List>{};
    void topla(Uint8List v) {
      for (final etiket in const [0x57, 0x5A, 0x5F24, 0x5F20]) {
        final d = tlvBul(v, etiket);
        if (d != null) bulunan.putIfAbsent(etiket, () => d);
      }
    }

    topla(gpo);
    final afl = gpo.isNotEmpty && gpo[0] == 0x80
        ? (gpo.length > 4 ? _deger(gpo) : null)?.sublist(2)
        : tlvBul(gpo, 0x94);
    if (!bulunan.containsKey(0x57) &&
        !bulunan.containsKey(0x5A) &&
        afl != null) {
      for (var i = 0; i + 3 < afl.length; i += 4) {
        final sfi = afl[i] >> 3;
        for (var r = afl[i + 1]; r <= afl[i + 2] && r != 0; r++) {
          final kayit = await _komut(
            gonder,
            Uint8List.fromList([0x00, 0xB2, r, (sfi << 3) | 4, 0x00]),
          );
          if (kayit != null) topla(kayit);
        }
      }
    }
    final k = kartBilgisiCoz(bulunan, simdi: simdi);
    if (k.numara != null) return k;
  }
  throw EmvHatasi(aidler.isEmpty ? 'uygulama_yok' : 'veri_yok');
}

/// Toplanan etiketlerden kart: numara Luhn'dan geçmeli; tarih geçmişte olamaz.
OkunanKart kartBilgisiCoz(Map<int, Uint8List> e, {required DateTime simdi}) {
  String? numara;
  int? ay, yil;
  final iz = e[0x57];
  if (iz != null) {
    final h = _hex(iz).toUpperCase();
    final ayrac = h.indexOf('D');
    if (ayrac >= 12 && h.length >= ayrac + 5) {
      numara = _numara(h.substring(0, ayrac));
      (ay, yil) = _tarih(h.substring(ayrac + 1, ayrac + 5));
    }
  }
  numara ??= e[0x5A] == null
      ? null
      : _numara(_hex(e[0x5A]!).toUpperCase().replaceAll('F', ''));
  if (ay == null && e[0x5F24] != null && e[0x5F24]!.length >= 2) {
    (ay, yil) = _tarih(_hex(e[0x5F24]!).substring(0, 4));
  }
  if (yil != null &&
      (yil < simdi.year || (yil == simdi.year && ay! < simdi.month))) {
    ay = yil = null;
  }
  return OkunanKart(
    numara: numara,
    ay: ay,
    yil: yil,
    ad: e[0x5F20] == null ? null : _ad(e[0x5F20]!),
  );
}

String? _numara(String rakamlar) {
  if (!RegExp(r'^[0-9]{13,19}$').hasMatch(rakamlar)) return null;
  try {
    return kartNumarasi(rakamlar);
  } catch (_) {
    return null;
  }
}

/// "YYMM" → (ay, yıl); bozuksa (null, null).
(int?, int?) _tarih(String yymm) {
  final yil = sktYili(yymm.substring(0, 2)),
      ay = int.tryParse(yymm.substring(2));
  if (yil == null || ay == null || ay < 1 || ay > 12) return (null, null);
  return (ay, yil);
}

/// EMV ad biçimi "SOYAD/AD"; boş, "/" veya harf dışı içerikte ad yok sayılır.
String? _ad(Uint8List b) {
  if (b.any((c) => c < 0x20 || c > 0x7E)) return null;
  final parca = String.fromCharCodes(b).split('/').map((s) => s.trim());
  final ad = [
    ...parca.skip(1),
    parca.first,
  ].where((s) => s.isNotEmpty).join(' ');
  return RegExp(r'^[A-Z][A-Z .\-]{1,58}$').hasMatch(ad) ? ad : null;
}

Future<List<String>> _dizin(ApduGonder gonder) async {
  final ppse = await _komut(
    gonder,
    _secim(_hex(Uint8List.fromList('2PAY.SYS.DDF01'.codeUnits))),
  );
  if (ppse == null) return const [];
  final aidler = <String>[];
  void gez(Uint8List v) {
    for (final (etiket, deger) in tlvListe(v)) {
      if (etiket == 0x4F) aidler.add(_hex(deger));
      if (_yapili(etiket)) gez(deger);
    }
  }

  gez(ppse);
  return aidler;
}

/// Kart yanıtının verisi (durum 90 00), değilse `null`. 61 xx: veri devamı
/// istenir; 6C xx: doğru uzunlukla yinelenir.
Future<Uint8List?> _komut(ApduGonder gonder, Uint8List komut) async {
  var c = komut;
  for (var deneme = 0; deneme < 3; deneme++) {
    final y = await gonder(c);
    if (y.length < 2) throw const EmvHatasi('yanit');
    final sw1 = y[y.length - 2], sw2 = y[y.length - 1];
    if (sw1 == 0x90 && sw2 == 0x00) return y.sublist(0, y.length - 2);
    if (sw1 == 0x61) {
      c = Uint8List.fromList([0x00, 0xC0, 0x00, 0x00, sw2]);
    } else if (sw1 == 0x6C) {
      c = Uint8List.fromList([...c.sublist(0, c.length - 1), sw2]);
    } else {
      return null;
    }
  }
  return null;
}

Uint8List _secim(String aidHex) {
  final aid = _bayt(aidHex);
  return Uint8List.fromList([0x00, 0xA4, 0x04, 0x00, aid.length, ...aid, 0x00]);
}

Uint8List _gpo(Uint8List pdolVerisi) => Uint8List.fromList([
  0x80, 0xA8, 0x00, 0x00, pdolVerisi.length + 2, //
  0x83, pdolVerisi.length, ...pdolVerisi, 0x00,
]);

/// Kartın istediği terminal verileri (PDOL). Tutar 0, ülke/para Türkiye,
/// tarih bugün, rastgele sayı sabit değil; bilinmeyenler sıfır.
Uint8List pdolDoldur(Uint8List pdol, DateTime simdi) {
  final cikti = <int>[];
  var i = 0;
  while (i < pdol.length) {
    final (etiket, ei) = _etiketOku(pdol, i);
    if (ei >= pdol.length) break;
    final uzunluk = pdol[ei];
    i = ei + 1;
    final deger = switch (etiket) {
      0x9F66 => [0x36, 0x20, 0x40, 0x00], // TTQ: temassız EMV, çevrimiçi
      0x9F1A => [0x07, 0x92], // Türkiye
      0x5F2A => [0x09, 0x49], // TRY
      0x9A => _bayt(
        '${simdi.year % 100}'.padLeft(2, '0') +
            '${simdi.month}'.padLeft(2, '0') +
            '${simdi.day}'.padLeft(2, '0'),
      ),
      0x9F37 => [
        for (var k = 0; k < 4; k++)
          (simdi.microsecondsSinceEpoch >> (k * 7)) & 0xFF,
      ],
      0x9F35 => [0x22],
      _ => <int>[],
    };
    cikti.addAll(
      List.generate(uzunluk, (k) => k < deger.length ? deger[k] : 0),
    );
  }
  return Uint8List.fromList(cikti);
}

/// BER-TLV: ilk düzeyden başlayarak iç içe yapılarda [etiket]'in ilk değeri.
Uint8List? tlvBul(Uint8List veri, int etiket) {
  for (final (e, d) in tlvListe(veri)) {
    if (e == etiket) return d;
    if (_yapili(e)) {
      final ic = tlvBul(d, etiket);
      if (ic != null) return ic;
    }
  }
  return null;
}

/// Bir düzeydeki (etiket, değer) çiftleri; bozuk uzunlukta durur.
List<(int, Uint8List)> tlvListe(Uint8List v) {
  final liste = <(int, Uint8List)>[];
  var i = 0;
  while (i < v.length) {
    if (v[i] == 0x00 || v[i] == 0xFF) {
      i++;
      continue;
    }
    final (etiket, ui) = _etiketOku(v, i);
    if (ui >= v.length) break;
    var uzunluk = v[ui], di = ui + 1;
    if (uzunluk & 0x80 != 0) {
      final n = uzunluk & 0x7F;
      if (n == 0 || n > 3 || di + n > v.length) break;
      uzunluk = 0;
      for (var k = 0; k < n; k++) {
        uzunluk = (uzunluk << 8) | v[di + k];
      }
      di += n;
    }
    if (di + uzunluk > v.length) break;
    liste.add((etiket, Uint8List.sublistView(v, di, di + uzunluk)));
    i = di + uzunluk;
  }
  return liste;
}

(int, int) _etiketOku(Uint8List v, int i) {
  var etiket = v[i], j = i + 1;
  if (etiket & 0x1F == 0x1F) {
    while (j < v.length) {
      etiket = (etiket << 8) | v[j];
      if (v[j++] & 0x80 == 0) break;
    }
  }
  return (etiket, j);
}

bool _yapili(int etiket) {
  var ilk = etiket;
  while (ilk > 0xFF) {
    ilk >>= 8;
  }
  return ilk & 0x20 != 0;
}

Uint8List? _deger(Uint8List v) {
  final l = tlvListe(v);
  return l.isEmpty ? null : l.first.$2;
}

String _hex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

Uint8List _bayt(String hex) => Uint8List.fromList([
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);
