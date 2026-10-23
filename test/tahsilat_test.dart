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
  CariEslesmesi eslesme = CariEslesmesi.tekGiris,
  DateTime? okunma,
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
  eslesme: eslesme,
  okunma: okunma,
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

  test('Kayıt kimliği JS ve kuralla aynı: başarısız deneme ayrı tutulur', () {
    for (final o in ornekler['kimlikler'] as List) {
      final sonuc = o[1] == 'hata' ? IslemSonucu.hata : IslemSonucu.basarili;
      expect(belgeKimligi(o[0] as String, sonuc), o[2]);
    }
    expect(posNoDuzelt('\u200eVP\u200b 100\u2060-a'), 'VP100-A');
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
        eslesme: CariEslesmesi.elle,
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

  test('Cari eşleşmesi kaynakla tutarlı olmalı', () {
    PosIslemi yap(IslemKaynagi k, CariEslesmesi e, {DateTime? okunma}) =>
        PosIslemi(
          posSiparisNo: 'VP1000',
          kullaniciId: 'u1',
          kullaniciAd: 'Örnek Kullanıcı',
          cariId: 'c1',
          cariAd: 'Örnek Zeytin Market',
          kimlikNo: '0000000001',
          sonuc: IslemSonucu.basarili,
          aciklama: 'Tamam',
          tutarMetni: '1',
          kaynak: k,
          eslesme: e,
          okunma: okunma,
        );
    const yer = IslemKaynagi.yerImi, elle = IslemKaynagi.elle;
    expect(() => yap(elle, CariEslesmesi.elle), returnsNormally);
    expect(() => yap(yer, CariEslesmesi.secim), returnsNormally);
    expect(() => yap(yer, CariEslesmesi.elle), throwsA(isA<PosHatasi>()));
    expect(() => yap(elle, CariEslesmesi.tekGiris), throwsA(isA<PosHatasi>()));
    expect(
      () => yap(elle, CariEslesmesi.elle, okunma: tr(22, 9)),
      throwsA(isA<PosHatasi>()),
    );
  });

  test('Eşleşme kodları sunucu kuralı ve sonuç sayfasıyla aynı', () {
    expect(CariEslesmesi.values.map((e) => e.kod), [
      'sonuc_ekrani',
      'kart_sayfasi',
      'tek_giris',
      'secim',
      'son_giris',
      'elle',
    ]);
    expect(CariEslesmesi.kodla('secim'), CariEslesmesi.secim);
    expect(CariEslesmesi.kodla('yok'), isNull);
    // Yeni sonuç sayfasının yazabileceği dördü: kural (artı 0.9.0'dan bekleyen
    // 'son_giris'), sonuç kutusu ve eşleştirici aynı listeyi kullanır.
    const yerImi = "'sonuc_ekrani', 'kart_sayfasi', 'tek_giris', 'secim'";
    expect(
      File('firestore.rules').readAsStringSync(),
      contains("[$yerImi, 'son_giris']"),
    );
    expect(
      File('web/sonuc_kutusu.js').readAsStringSync(),
      contains('[$yerImi]'),
    );
    final eslestir = File('web/cari_eslestir.js').readAsStringSync();
    for (final k in ['sonuc_ekrani', 'kart_sayfasi', 'tek_giris']) {
      expect(eslestir, contains("'$k'"));
    }
  });

  test('Geç okunan sonuç (Sanal POS’a geç dönüş) ayrıca bilinir', () {
    expect(islem('VP1000', 'c1', tr(22, 9)).gecOkunma, isNull);
    expect(
      islem('VP1000', 'c1', tr(22, 9), okunma: tr(22, 8, 55)).gecOkunma,
      isNull,
    );
    expect(
      islem('VP1000', 'c1', tr(23, 0, 5), okunma: tr(22, 23, 50)).gecOkunma,
      tr(22, 23, 50),
    );
    expect(tarihSaatYaz(tr(22, 23, 50)), '22.10.2026 23:50');
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
      expect(
        csv.split('\r\n').first,
        endsWith('"Cari eşleşmesi";"Sonuç okunma (telefon saati)"'),
      );
      expect(satir, endsWith('"Telefondaki tek DenizPay girişiyle";""'));
      final gec = gunSonuCsv(
        GunSonu.hesapla(gun, [], [
          islem(
            'VP0010',
            'c1',
            tr(22, 0, 10),
            eslesme: CariEslesmesi.secim,
            okunma: tr(21, 23, 58),
          ),
        ]),
      ).split('\r\n')[1];
      expect(gec, endsWith('"Kaydeden kişinin seçimiyle";"21.10.2026 23:58"'));
      expect(csv.endsWith('\r\n'), isTrue);
    });
  });
}
