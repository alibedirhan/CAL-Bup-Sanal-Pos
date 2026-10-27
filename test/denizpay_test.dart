import 'dart:convert';
import 'dart:io';
import 'package:bup_sanal_pos/domain/denizpay.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sonuç ekranı okuma (web sonuc_coz.js ile aynı örnekler)', () {
    final ornekler =
        (jsonDecode(
                  File('test/veri/tahsilat_ornekleri.json').readAsStringSync(),
                )
                as Map)['sonuclar']
            as List;
    // Yalnız web yer iminin sekme notu biçimini sınar; Android'de yer imi yoktur.
    const yalnizWeb = {
      'Sekme notu biçimsiz: reddedilir',
      'Eski yer imi özeti (sekme alanı yok): reddedilir',
    };

    test('Örnekler okunuyor ve yalnız web örnekleri ayrılıyor', () {
      expect(ornekler, hasLength(19));
      final adlar = ornekler.map((o) => o['ad']).toSet();
      expect(adlar.containsAll(yalnizWeb), isTrue);
    });

    for (final o in ornekler.cast<Map>()) {
      final ad = o['ad'] as String;
      if (yalnizWeb.contains(ad)) continue;
      test(ad, () {
        final sayfa = o['sayfa'] as Map;
        final ozet = SayfaOzeti.oku({
          'metin': sayfa['metin'],
          'alanlar': sayfa['alanlar'],
          'firma': sayfa['firma'],
          'kartAlanlari': false,
        });
        final b = o['beklenen'] as Map;
        if (ozet == null) {
          expect(b['ok'], isFalse, reason: 'biçimsiz özet okunmaz');
          return;
        }
        final r = sonucCoz(ozet);
        expect(r.sonuc != null, b['ok'], reason: r.hata);
        if (r.sonuc case final s?) {
          expect(s.sonuc.name, b['sonuc']);
          expect(s.aciklama, b['aciklama']);
          expect(s.posSiparisNo, b['posSiparisNo']);
          expect(s.uyeSiparisNo, b['uyeSiparisNo']);
          expect(s.tutarMetni, b['tutarMetni']);
          expect(s.tutarKurus, b['tutarKurus']);
        } else {
          expect(r.hata, isNotEmpty);
        }
      });
    }
  });

  group('Sayfa özeti biçimi', () {
    Map<String, Object?> gecerli() => {
      'metin': 'Onay Formu',
      'alanlar': [
        ['Tutar', '1'],
      ],
      'firma': '0000000001',
      'kartAlanlari': true,
    };
    test('Geçerli özet okunur', () {
      final o = SayfaOzeti.oku(gecerli())!;
      expect(o.firma, '0000000001');
      expect(o.kartAlanlari, isTrue);
      expect(o.alanlar.single, ('Tutar', '1'));
    });
    test('Fazla/eksik alan, uzun yazı, biçimsiz firma reddedilir', () {
      for (final bozuk in <Map<String, Object?>>[
        {...gecerli(), 'fazla': 1},
        Map.of(gecerli())..remove('firma'),
        {...gecerli(), 'metin': 'x' * 5001},
        {...gecerli(), 'firma': '12'},
        {...gecerli(), 'firma': 1234567890},
        {
          ...gecerli(),
          'alanlar': [
            ['a', 'b', 'c'],
          ],
        },
        {
          ...gecerli(),
          'alanlar': [
            ['a', 'x' * 201],
          ],
        },
        {
          ...gecerli(),
          'alanlar': List.filled(41, ['a', 'b']),
        },
        {...gecerli(), 'kartAlanlari': 'evet'},
      ]) {
        expect(SayfaOzeti.oku(bozuk), isNull, reason: '$bozuk');
      }
      expect(SayfaOzeti.oku('metin'), isNull);
    });
  });

  group('Gezinme kuralı', () {
    final canli = DenizPayAdresi.canli;
    Gezinme k(String u, [DenizPayAdresi? a]) =>
        (a ?? canli).karar(Uri.parse(u));

    test('Canlı: yalnız DenizPay okunur; diğer https açılır, betik yok', () {
      expect(
        canli.giris.toString(),
        'https://denizpay.bupilic.com.tr/login.aspx',
      );
      expect(k('https://denizpay.bupilic.com.tr/index.aspx'), Gezinme.denizPay);
      expect(k('https://acs.banka.example/3d'), Gezinme.disSite);
      expect(k('about:blank'), Gezinme.disSite);
      // Benzer ad, alt alan adı, farklı bağlantı noktası DenizPay sayılmaz.
      for (final u in [
        'https://denizpay.bupilic.com.tr.kotu.example/',
        'https://x.denizpay.bupilic.com.tr/',
        'https://denizpay.bupilic.com.tr:8443/',
      ]) {
        expect(k(u), isNot(Gezinme.denizPay), reason: u);
      }
    });

    test(
      'Canlı: http, intent, javascript, file, data, kullanıcı bilgili adres engellenir',
      () {
        for (final u in [
          'http://denizpay.bupilic.com.tr/login.aspx',
          'http://acs.banka.example/',
          'intent://x#Intent;scheme=https;end',
          'javascript:alert(1)',
          'file:///sdcard/a.html',
          'data:text/html,<p>x</p>',
          'https://kullanici:sifre@acs.banka.example/',
          'market://details?id=x',
        ]) {
          expect(k(u), Gezinme.engel, reason: u);
        }
      },
    );

    test(
      'Yalnız taklit (http) kökende aynı makinedeki taklit banka açılır',
      () {
        final t = DenizPayAdresi(Uri.parse('http://10.0.2.2:4199'));
        expect(k('http://10.0.2.2:4199/kart.aspx', t), Gezinme.denizPay);
        expect(k('http://10.0.2.2:4200/3d', t), Gezinme.disSite);
        expect(k('http://192.168.1.5:4200/3d', t), Gezinme.engel);
        expect(t.giris.toString(), 'http://10.0.2.2:4199/login.aspx');
      },
    );
  });

  test('Okunan sonucun tutarı kuruşa çevrilir', () {
    const s = OkunanSonuc(
      sonuc: IslemSonucu.basarili,
      aciklama: 'Ödeme Başarıyla Gerçekleştirildi',
      posSiparisNo: 'VP1',
      uyeSiparisNo: '',
      tutarMetni: '4.500,00',
    );
    expect(s.tutarKurus, 450000);
  });
}
