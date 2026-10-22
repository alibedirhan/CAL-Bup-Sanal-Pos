import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/domain/gun_sonu.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';

PosGirisi giris(String id, String cari, DateTime zaman, {String uid = 'u1'}) =>
    PosGirisi(
      id: id.padRight(20, '0'),
      kullaniciId: uid,
      kullaniciAd: 'Örnek Kullanıcı',
      cariId: cari,
      cariAd: cari == 'c1' ? 'Örnek Zeytin Market' : 'Örnek Ada Gıda',
      kimlikNo: cari == 'c1' ? '0000000001' : '0000000002',
      zaman: zaman,
    );

PosIslemi islem(
  String no,
  String cari,
  DateTime zaman, {
  IslemSonucu sonuc = IslemSonucu.basarili,
  String tutar = '4500',
  String aciklama = 'Ödeme Başarıyla Gerçekleştirildi',
  String cariAd = '',
}) => PosIslemi(
  posSiparisNo: no,
  kullaniciId: 'u1',
  kullaniciAd: 'Örnek Kullanıcı',
  cariId: cari,
  cariAd: cariAd.isNotEmpty
      ? cariAd
      : cari == 'c1'
      ? 'Örnek Zeytin Market'
      : 'Örnek Ada Gıda',
  kimlikNo: cari == 'c1' ? '0000000001' : '0000000002',
  sonuc: sonuc,
  aciklama: aciklama,
  tutarMetni: tutar,
  kaynak: IslemKaynagi.yerImi,
  zaman: zaman,
);

// 22 Ekim 2026, Türkiye saati = UTC+3.
DateTime tr(int gun, int saat, [int dakika = 0]) => DateTime.utc(
  2026,
  10,
  gun,
  saat,
  dakika,
).subtract(const Duration(hours: 3));

void main() {
  final ornekler =
      jsonDecode(File('test/veri/tahsilat_ornekleri.json').readAsStringSync())
          as Map<String, dynamic>;

  test('Tutar yazısı JS ile aynı örneklerle kuruşa çevrilir', () {
    for (final o in ornekler['tutarlar'] as List) {
      expect(tutarCoz(o[0] as String), o[1], reason: '"${o[0]}"');
    }
  });

  test('Tutar Türkçe biçimde yazılır', () {
    expect(tutarYaz(450000), '4.500,00 TL');
    expect(tutarYaz(4567890), '45.678,90 TL');
    expect(tutarYaz(99), '0,99 TL');
    expect(tutarYaz(123456789), '1.234.567,89 TL');
  });

  test('Gün Türkiye saatiyle 00:00’da başlar, cihaz saat dilimine bakmaz', () {
    final gun = Gun.ani(tr(22, 10));
    expect(gun, const Gun(2026, 10, 22));
    expect(gun.baslangic, DateTime.utc(2026, 10, 21, 21));
    expect(gun.bitis, DateTime.utc(2026, 10, 22, 21));
    expect(Gun.ani(tr(22, 23, 59)), gun);
    expect(Gun.ani(tr(23, 0)), const Gun(2026, 10, 23));
    // UTC'de hâlâ 22 Ekim 21:30 ama Türkiye'de 23 Ekim 00:30.
    expect(Gun.ani(DateTime.utc(2026, 10, 22, 21, 30)), gun.sonraki);
    expect(gun.onceki, const Gun(2026, 10, 21));
    expect(const Gun(2026, 11, 1).onceki, const Gun(2026, 10, 31));
    expect(const Gun(2026, 12, 31).sonraki, const Gun(2027, 1, 1));
    expect(gun.etiket, '22.10.2026');
    expect(gun.anahtar, '2026-10-22');
    expect(gun.kapandi(tr(22, 23, 59)), isFalse);
    expect(gun.kapandi(tr(23, 0)), isTrue);
    expect(saatYaz(tr(22, 10, 48)), '10:48');
  });

  test('Pos Sipariş Numarası düzeltilir; geçersizi reddedilir', () {
    expect(posNoDuzelt(' vp 1000 2000 '), 'VP10002000');
    for (final kotu in ['', 'VP1', 'VP/12345', 'VP 12;34']) {
      expect(() => posNoDuzelt(kotu), throwsA(isA<PosHatasi>()), reason: kotu);
    }
  });

  test('İşlem kaydı VKN, kart ve giriş kimliğini denetler', () {
    expect(islem('VP1000', 'c1', tr(22, 9)).tutarKurus, 450000);
    expect(
      islem('VP1000', 'c1', tr(22, 9), tutar: '4,500.00').tutarKurus,
      null,
    );
    expect(
      () => PosIslemi(
        posSiparisNo: 'VP1000',
        kullaniciId: 'u1',
        kullaniciAd: 'Örnek Kullanıcı',
        cariId: 'c1',
        cariAd: 'Örnek Zeytin Market',
        kimlikNo: '12',
        sonuc: IslemSonucu.basarili,
        aciklama: 'Tamam',
        tutarMetni: '1',
        kaynak: IslemKaynagi.elle,
      ),
      throwsA(isA<PosHatasi>()),
    );
    expect(() => giris('kisa', 'c1', tr(22, 9)).kartSonDort, returnsNormally);
    expect(
      () => PosGirisi(
        id: 'kisa',
        kullaniciId: 'u1',
        kullaniciAd: 'Örnek Kullanıcı',
        cariId: 'c1',
        cariAd: 'Örnek Zeytin Market',
        kimlikNo: '0000000001',
      ),
      throwsA(isA<PosHatasi>()),
    );
  });

  group('Gün sonu', () {
    final gun = const Gun(2026, 10, 22);
    final g = GunSonu.hesapla(
      gun,
      [
        giris('a', 'c1', tr(22, 9)),
        giris('b', 'c1', tr(22, 11)),
        giris('c', 'c2', tr(22, 14)),
        giris('d', 'c2', tr(21, 23, 59)), // önceki gün
      ],
      [
        islem(
          'VP0001',
          'c1',
          tr(22, 9, 5),
          sonuc: IslemSonucu.hata,
          aciklama: '3D Şifresi Yanlış.',
        ),
        islem('VP0002', 'c1', tr(22, 9, 8)),
        islem('VP0003', 'c1', tr(22, 11, 2), tutar: '12.750,50'),
        islem('VP0004', 'c2', tr(23, 0, 1)), // ertesi gün
        islem('VP0005', 'c2', tr(22, 13), tutar: 'okunmaz'),
      ],
    );

    test('Yalnız o günün kayıtları, cari adına göre sıralı', () {
      expect(g.cariler.map((c) => c.cariAd), [
        'Örnek Ada Gıda',
        'Örnek Zeytin Market',
      ]);
      expect(g.islemler.map((i) => i.posSiparisNo), [
        'VP0005',
        'VP0001',
        'VP0002',
        'VP0003',
      ]);
    });

    test('Toplam yalnız başarılı ve okunabilen tutardır', () {
      final c1 = g.cariler.last;
      expect(c1.toplamKurus, 450000 + 1275050);
      expect(c1.basariliAdet, 2);
      expect(c1.hataAdet, 1);
      expect(c1.girisSayisi, 2);
      expect(g.toplamKurus, 1725050);
      expect(g.okunamayanAdet, 1);
      expect(g.basariliAdet, 3);
      expect(g.hataAdet, 1);
    });

    test('Son girişten sonra sonuç yoksa uyarılır', () {
      expect(g.sonucBekleyenler.map((c) => c.cariId), ['c2']);
      expect(g.cariler.last.sonucBekliyor, isFalse);
    });

    test('Cari adı en son kayıttan alınır', () {
      final s = GunSonu.hesapla(
        gun,
        [giris('a', 'c1', tr(22, 9))],
        [islem('VP0001', 'c1', tr(22, 10), cariAd: 'Örnek Zeytin Market Yeni')],
      );
      expect(s.cariler.single.cariAd, 'Örnek Zeytin Market Yeni');
      expect(GunSonu.hesapla(gun, [], []).bos, isTrue);
    });

    test('CSV Excel’in Türkçe ayarına uygun ve formül çalıştırmaz', () {
      final csv = gunSonuCsv(
        GunSonu.hesapla(gun, [], [
          islem(
            'VP0009',
            'c1',
            tr(22, 10, 48),
            tutar: '45678,90',
            cariAd: '=HYPERLINK("x") Örnek',
          ),
        ]),
      );
      expect(csv.startsWith('﻿"Tarih";"Saat";"Cari"'), isTrue);
      final satir = csv.split('\r\n')[1];
      expect(
        satir,
        contains('"22.10.2026";"10:48";"\'=HYPERLINK(""x"") Örnek"'),
      );
      expect(satir, contains('"45678,90";"45678,90";"VP0009"'));
      expect(satir, contains('"Başarılı"'));
      expect(csv.endsWith('\r\n'), isTrue);
    });
  });
}
