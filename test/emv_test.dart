import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/domain/emv.dart';

/// Yapay temassız kart: komut (onaltılık) → yanıt (onaltılık, durumla).
/// Yalnız test kart numaraları (4111…, 5555…) kullanılır.
class _Kart {
  _Kart(this.yanitlar);
  final Map<String, String> yanitlar;
  final komutlar = <Uint8List>[];
  Future<Uint8List> gonder(Uint8List c) async {
    komutlar.add(c);
    final h = hex(c);
    for (final MapEntry(:key, :value) in yanitlar.entries) {
      if (h.startsWith(key)) return bayt(value);
    }
    return bayt('6A82');
  }
}

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
Uint8List bayt(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);
String tlv(String etiket, String deger) {
  final n = deger.length ~/ 2;
  final u = n < 0x80
      ? n.toRadixString(16).padLeft(2, '0')
      : '81${n.toRadixString(16).padLeft(2, '0')}';
  return '$etiket$u$deger'.toUpperCase();
}

String metin(String s) => hex(s.codeUnits);

const ppseSecim = '00A404000E325041592E5359532E4444463031';
String ppse(List<String> aidler) => tlv(
  '6F',
  tlv('84', metin('2PAY.SYS.DDF01')) +
      tlv(
        'A5',
        tlv('BF0C', [for (final a in aidler) tlv('61', tlv('4F', a))].join()),
      ),
);
String secim(String aid) =>
    '00A40400${(aid.length ~/ 2).toRadixString(16).padLeft(2, '0')}$aid'
        .toUpperCase();

final simdi = DateTime(2026, 10, 27);

void main() {
  test('Visa benzeri: PDOL doldurulur, numara ve tarih GPO yanıtından', () async {
    const aid = 'A0000000031010';
    final kart = _Kart({
      ppseSecim: '${ppse([aid])}9000',
      secim(
        aid,
      ): '${tlv('6F', tlv('84', aid) + tlv('A5', tlv('9F38', '9F66049F02069F37045F2A029A039F1A02')))}9000',
      '80A8':
          '${tlv('77', tlv('82', '2000') + tlv('57', '4111111111111111D30122010000000000000F'))}9000',
    });
    final k = await emvKartOku(kart.gonder, simdi: simdi);
    expect((k.numara, k.ay, k.yil, k.ad), ('4111111111111111', 12, 2030, null));
    final gpo = kart.komutlar.firstWhere((c) => c[0] == 0x80 && c[1] == 0xA8);
    // 83 + uzunluk 21: TTQ, tutar 0, rastgele, TRY, tarih, Türkiye.
    expect(hex(gpo).substring(10, 14), '8315');
    expect(hex(gpo), contains('36204000000000000000'));
    expect(hex(gpo), contains('0949261027'));
    expect(hex(gpo), endsWith('079200'));
  });

  test(
    'Mastercard benzeri: kayıt yerleri okunur; ad SOYAD/AD → AD SOYAD',
    () async {
      const aid = 'A0000000041010';
      final kart = _Kart({
        ppseSecim: '${ppse([aid])}9000',
        secim(
          aid,
        ): '${tlv('6F', tlv('84', aid) + tlv('A5', tlv('50', metin('MASTERCARD'))))}9000',
        '80A8000002830000':
            '${tlv('80', '1980'
                '08010100')}9000',
        '00B2010C':
            '${tlv('70', tlv('5A', '5555555555554444') + tlv('5F24', '310831') + tlv('5F20', metin('ORNEK/KISI')))}9000',
      });
      final k = await emvKartOku(kart.gonder, simdi: simdi);
      expect(
        (k.numara, k.ay, k.yil, k.ad),
        ('5555555555554444', 8, 2031, 'KISI ORNEK'),
      );
    },
  );

  test(
    'Dizin (PPSE) yoksa bilinen uygulamalar denenir; 61 xx devamı alınır',
    () async {
      const aid = 'A0000000041010';
      final kart = _Kart({
        secim(aid): '6110',
        '00C0000010': '${tlv('6F', tlv('84', aid))}9000',
        '80A8':
            '${tlv('77', tlv('5A', '5555555555554444') + tlv('5F24', '300131'))}9000',
      });
      final k = await emvKartOku(kart.gonder, simdi: simdi);
      expect((k.numara, k.ay, k.yil), ('5555555555554444', 1, 2030));
    },
  );

  test(
    'Ödeme komutu gönderilmez: yalnız seçim, GPO, kayıt okuma, devam',
    () async {
      const aid = 'A0000000041010';
      final kart = _Kart({
        ppseSecim: '${ppse([aid])}9000',
        secim(aid): '${tlv('6F', tlv('84', aid))}9000',
        '80A8':
            '${tlv('80', '1980'
                '08010200'
                '10010100')}9000',
        '00B2010C': '${tlv('70', tlv('9F07', 'FF00'))}9000',
        '00B2020C': '${tlv('70', tlv('5A', '5555555555554444'))}9000',
      });
      await emvKartOku(kart.gonder, simdi: simdi);
      for (final c in kart.komutlar) {
        expect(
          ['00A4', '80A8', '00B2', '00C0'].contains(hex(c.sublist(0, 2))),
          isTrue,
          reason: hex(c),
        );
      }
      // AFL'deki bütün kayıtlar okunur (tarih başka kayıtta olabilir).
      expect(
        kart.komutlar.where((c) => hex(c).startsWith('00B20114')),
        isNotEmpty,
      );
    },
  );

  test('Luhn tutmayan numara, kartta uygulama yok, bozuk yanıt', () async {
    const aid = 'A0000000031010';
    await expectLater(
      emvKartOku(
        _Kart({
          ppseSecim: '${ppse([aid])}9000',
          secim(aid): '${tlv('6F', tlv('84', aid))}9000',
          '80A8': '${tlv('77', tlv('57', '4111111111111112D3012201F'))}9000',
        }).gonder,
        simdi: simdi,
      ),
      throwsA(isA<EmvHatasi>().having((e) => e.kod, 'kod', 'veri_yok')),
    );
    await expectLater(
      emvKartOku(_Kart({}).gonder, simdi: simdi),
      throwsA(isA<EmvHatasi>().having((e) => e.kod, 'kod', 'uygulama_yok')),
    );
    await expectLater(
      emvKartOku(_Kart({ppseSecim: '90'}).gonder, simdi: simdi),
      throwsA(isA<EmvHatasi>().having((e) => e.kod, 'kod', 'yanit')),
    );
  });

  test('Süresi geçmiş tarih ve bozuk ad alınmaz, numara kalır', () {
    final k = kartBilgisiCoz({
      0x5A: bayt('4111111111111111'),
      0x5F24: bayt('250131'),
      0x5F20: bayt('202F20'),
    }, simdi: simdi);
    expect(
      (k.numara, k.ay, k.yil, k.ad),
      ('4111111111111111', null, null, null),
    );
    // Tek sayıda hanede numara F ile doldurulur; F atılır.
    expect(
      kartBilgisiCoz({0x5A: bayt('6250941006528599F0')}, simdi: simdi).numara,
      isNull, // 17 hane + 0: Luhn tutmaz
    );
    expect(
      kartBilgisiCoz({0x5A: bayt('411111111111111F')}, simdi: simdi).numara,
      isNull, // 15 hane: Luhn tutmaz
    );
    expect(
      kartBilgisiCoz({0x5A: bayt('6250941006528599')}, simdi: simdi).numara,
      '6250941006528599',
    );
  });

  test('TLV: çok baytlı etiket ve uzunluk, dolgu baytları, bozuk uzunluk', () {
    final uzun = 'AB' * 200;
    final v = bayt(
      '00${tlv('70', tlv('9F38', '9F6604') + tlv('5F20', uzun))}FF',
    );
    expect(hex(tlvBul(v, 0x9F38)!), '9F6604');
    expect(tlvBul(v, 0x5F20)!.length, 200);
    expect(tlvListe(bayt('5A08411111')), isEmpty);
    expect(pdolDoldur(bayt('9F02069F1A029F9999'), simdi).length, 6 + 2);
  });
}
