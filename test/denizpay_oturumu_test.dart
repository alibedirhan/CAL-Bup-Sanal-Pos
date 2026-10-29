import 'dart:async';
import 'package:bup_sanal_pos/application/denizpay_oturumu.dart';
import 'package:bup_sanal_pos/domain/bekleyen_sonuc.dart';
import 'package:bup_sanal_pos/domain/denizpay.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/domain/pos_girisi.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';
import 'package:flutter_test/flutter_test.dart';

const vkn = '0000000001';

class SahteTarayici implements DenizPayTarayicisi {
  final olaylar = <String>[];
  Object? ozet;
  Completer<Object?>? bekleyenOzet;
  String yazmaSonucu = 'tamam';
  Map<String, Object?>? yazilan;
  @override
  Future<void> temizle() async => olaylar.add('temizle');
  @override
  Future<void> girisYap(Uri adres, PosGirisBilgisi giris) async =>
      olaylar.add('giris $adres ${giris.vergiNo} ${giris.sifre}');
  @override
  Future<Object?> ozetAl() async {
    olaylar.add('ozet');
    return bekleyenOzet?.future ?? ozet;
  }

  @override
  Future<String> kartiYaz({
    required String numara,
    required String sahibi,
    required int ay,
    required int yil,
    required String kimlikNo,
  }) async {
    yazilan = {
      'numara': numara,
      'sahibi': sahibi,
      'ay': ay,
      'yil': yil,
      'kimlikNo': kimlikNo,
    };
    return yazmaSonucu;
  }
}

class SahteBirakma implements SonucBirakmaPortu {
  final birakilan = <Map<String, Object?>>[];

  /// Doluysa bırakma bu hatayla başarısız olur (telefonda saklanamadı).
  Object? hata;
  final _yanit =
      StreamController<({String kimlik, bool tamam, String mesaj})>.broadcast(
        sync: true,
      );
  @override
  Future<String> birak(Map<String, Object?> kayit) async {
    if (hata case final h?) throw h;
    birakilan.add(kayit);
    return 'ok';
  }

  void yanitla(String kimlik, bool tamam, String mesaj) =>
      _yanit.add((kimlik: kimlik, tamam: tamam, mesaj: mesaj));
  @override
  Stream<({String kimlik, bool tamam, String mesaj})> get yanitlar =>
      _yanit.stream;
}

Map<String, Object?> kartSayfasi({String? firma = vkn, bool kutular = true}) =>
    {
      'metin': 'Ödeme\nFirma İsmi : ÖRNEK ($firma)',
      'alanlar': <List<String>>[],
      'firma': firma,
      'kartAlanlari': kutular,
    };

Map<String, Object?> sonucSayfasi({
  String form = 'Onay Formu',
  String? firma,
  String pos = 'VP10000000000000001',
}) => {
  'metin': form,
  'alanlar': [
    ['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi'],
    ['Pos Sipariş Numarası', pos],
    ['Tutar', '4.500,00'],
  ],
  'firma': firma,
  'kartAlanlari': false,
};

void main() {
  final koken = DenizPayAdresi(Uri.parse('https://denizpay.bupilic.com.tr'));
  final kart = KartOzeti(
    id: 'k1',
    cariId: 'c1',
    ad: 'Örnek İş Kartı',
    sonDort: '1111',
    ay: 12,
    yil: 2030,
    cihazKayitId: 'r1',
  );
  late SahteTarayici t;
  late SahteBirakma b;
  late List<String> okumalar;
  KartBilgileri? Function() okunan = () =>
      KartBilgileri(numara: '4111111111111111', sahibi: 'ÖRNEK KİŞİ');

  DenizPayOturumu oturum({KartOzeti? secili}) => DenizPayOturumu(
    baglam: DenizPayBaglami(
      giris: PosGirisBilgisi.kimlikten(vkn),
      kayit: PosGirisi(
        id: 'G' * 20,
        kullaniciId: 'u1',
        kullaniciAd: 'Örnek Satıcı',
        cariId: 'c1',
        cariAd: 'Örnek Market',
        kimlikNo: vkn,
        kartSonDort: secili?.sonDort ?? '',
      ),
      kart: secili,
    ),
    tarayici: t,
    adres: koken,
    birakma: b,
    kartiOku: () async {
      okumalar.add('oku');
      return okunan();
    },
    saat: () => DateTime.utc(2026, 10, 27, 9),
  );
  Uri sayfa(String yol) => Uri.parse('https://denizpay.bupilic.com.tr$yol');

  setUp(() {
    t = SahteTarayici();
    b = SahteBirakma();
    okumalar = [];
    okunan = () =>
        KartBilgileri(numara: '4111111111111111', sahibi: 'ÖRNEK KİŞİ');
  });

  test('Açılışta önceki oturum silinir, sonra bu cariyle girilir', () async {
    await oturum().baslat();
    expect(t.olaylar, [
      'temizle',
      'giris https://denizpay.bupilic.com.tr/login.aspx $vkn 0001',
    ]);
  });

  test('Banka sayfasında betik çalıştırılmaz', () async {
    final o = oturum(secili: kart);
    await o.sayfaYuklendi(Uri.parse('https://acs.banka.example/3d'));
    expect(t.olaylar, isEmpty);
    expect(o.durum.sayfa, DenizPaySayfasi.disSite);
    expect(o.kartDoldurulabilir, isFalse);
  });

  test('Kart sayfası, firma aynı: kart sunucuda doğrulanıp yazılır', () async {
    final o = oturum(secili: kart);
    t.ozet = kartSayfasi();
    await o.sayfaYuklendi(sayfa('/odeme.aspx'));
    expect(o.durum.sayfa, DenizPaySayfasi.kart);
    expect(o.kartDoldurulabilir, isTrue);
    await o.kartiDoldur();
    expect(okumalar, ['oku']);
    expect(t.yazilan, {
      'numara': '4111111111111111',
      'sahibi': 'ÖRNEK KİŞİ',
      'ay': 12,
      'yil': 2030,
      'kimlikNo': vkn,
    });
    expect(o.durum.not, startsWith('Kart yazıldı (•••• 1111)'));
    expect(o.durum.notHata, isFalse);
  });

  test(
    'Firma farklı veya yoksa, ya da kart seçilmediyse kart yazılmaz',
    () async {
      for (final (s, secili) in [
        (kartSayfasi(firma: '0000000009'), kart),
        (kartSayfasi(firma: null), kart),
        (kartSayfasi(), null),
        (
          kartSayfasi(),
          KartOzeti(
            id: 'k2',
            cariId: 'c1',
            ad: 'Başka cihaz kartı',
            sonDort: '1111',
            ay: 12,
            yil: 2030,
          ),
        ),
      ]) {
        final o = oturum(secili: secili);
        t.ozet = s;
        await o.sayfaYuklendi(sayfa('/odeme.aspx'));
        expect(o.kartDoldurulabilir, isFalse, reason: '$s $secili');
        await o.kartiDoldur();
      }
      expect(okumalar, isEmpty);
      expect(t.yazilan, isNull);
    },
  );

  test(
    'Kartın tam bilgisi yoksa, doğrulama reddederse, sayfa farklıysa söylenir',
    () async {
      final o = oturum(secili: kart);
      t.ozet = kartSayfasi();
      await o.sayfaYuklendi(sayfa('/odeme.aspx'));
      okunan = () => null;
      await o.kartiDoldur();
      expect(o.durum.not, contains('tam bilgisi bu telefonda yok'));
      okunan = () => throw const PosHatasi('surum', 'Kart bilgisi değişti.');
      await o.kartiDoldur();
      expect(o.durum.not, 'Kart bilgisi değişti.');
      expect(o.durum.notHata, isTrue);
      okunan = () => KartBilgileri(numara: '4111111111111111');
      for (final (kod, parca) in [
        ('firma', 'cariye ait değil'),
        ('eksik', 'tam yazılamadı'),
        ('kutu', 'bulunamadı'),
      ]) {
        t.yazmaSonucu = kod;
        await o.kartiDoldur();
        expect(o.durum.not, contains(parca));
        expect(o.durum.notHata, isTrue);
      }
    },
  );

  test(
    'Sonuç ekranı okunur; düğme beklemeden bu cariye v3 kayıt bırakılır',
    () async {
      final o = oturum(secili: kart);
      t.ozet = sonucSayfasi();
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      expect(o.durum.sayfa, DenizPaySayfasi.sonuc);
      expect(o.durum.sonuc!.tutarKurus, 450000);
      expect(b.birakilan, hasLength(1), reason: 'kendiliğinden kaydedilir');
      expect(o.durum.birakildi, isTrue);
      await o.sonucuKaydet(); // düğmeye yine basılsa ikinci kayıt yok
      expect(b.birakilan, hasLength(1));
      final k = b.birakilan.single;
      expect(k['v'], 3);
      expect(k['eslesme'], 'uygulama_ici');
      expect(k['cariId'], 'c1');
      expect(k['kartSonDort'], '1111');
      // Kayıt, kutuyu işleyen servisin okuyacağı biçimde.
      final bs = BekleyenSonuc.oku(k, 'Örnek Satıcı')!;
      expect(bs.islem.kaynak, IslemKaynagi.uygulama);
      expect(bs.islem.eslesme, CariEslesmesi.uygulamaIci);
      expect(bs.islem.kimlik, 'VP10000000000000001');
      b.yanitla('VP99', true, 'başka sonuç');
      expect(o.durum.kayitNotu, 'Kaydediliyor…');
      b.yanitla('VP10000000000000001', true, 'Kaydedildi: Örnek Market');
      expect(o.durum.kayitNotu, 'Kaydedildi: Örnek Market');
      expect(o.durum.kayitTamam, isTrue);
    },
  );

  test('Başarısız sonuç "-h" kimliğiyle eşleşir', () async {
    final o = oturum();
    t.ozet = {
      ...sonucSayfasi(form: 'Hata Formu'),
      'alanlar': [
        ['Açıklama', '3D Şifresi Yanlış.'],
        ['Pos Sipariş Numarası', 'VP2000'],
        ['Tutar', '100'],
      ],
    };
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    expect(o.durum.sonuc!.sonuc, IslemSonucu.hata);
    expect(b.birakilan.single['kartSonDort'], '');
    b.yanitla('VP2000-h', false, 'bekliyor');
    expect(o.durum.kayitNotu, 'bekliyor');
  });

  test('Başka firmanın veya okunamayan sonuç ekranı kaydedilemez', () async {
    final o = oturum();
    t.ozet = sonucSayfasi(firma: '0000000009');
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    expect(o.durum.sonuc, isNull);
    expect(o.durum.sonucHatasi, contains('seçili cariye ait değil'));
    t.ozet = {...sonucSayfasi(), 'alanlar': <List<String>>[]};
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    expect(o.durum.sayfa, DenizPaySayfasi.sonuc);
    expect(o.durum.sonucHatasi, contains('elle kaydet'));
    await o.sonucuKaydet();
    expect(b.birakilan, isEmpty);
  });

  test(
    'Aynı sonuç ekranı yeniden yüklenirse ikinci kez bırakılmaz, not kalır',
    () async {
      final o = oturum(secili: kart);
      t.ozet = sonucSayfasi();
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      b.yanitla('VP10000000000000001', true, 'Kaydedildi: Örnek Market');
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      expect(b.birakilan, hasLength(1));
      expect(o.durum.birakildi, isTrue);
      expect(o.durum.kayitNotu, 'Kaydedildi: Örnek Market');
      expect(o.durum.kayitTamam, isTrue);
      // Aynı numarada ama başarısız sonuç ayrı belgedir ("-h"): bırakılır.
      t.ozet = {
        ...sonucSayfasi(form: 'Hata Formu'),
        'alanlar': [
          ['Açıklama', 'Yetersiz bakiye'],
          ['Pos Sipariş Numarası', 'VP10000000000000001'],
          ['Tutar', '4.500,00'],
        ],
      };
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      expect(b.birakilan, hasLength(2));
      expect(b.birakilan.last['sonuc'], 'hata');
    },
  );

  test(
    'Bırakma başarısızsa düğme kalır, uyarı görünür; yeniden denenir',
    () async {
      final o = oturum(secili: kart);
      b.hata = StateError('depo');
      t.ozet = sonucSayfasi();
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      expect(b.birakilan, isEmpty);
      expect(o.durum.birakildi, isFalse);
      expect(o.durum.kayitHata, isTrue);
      expect(o.durum.kayitNotu, contains('elle kaydet'));
      expect(o.durum.mesgul, isFalse);
      b.hata = null;
      await o.sonucuKaydet();
      expect(b.birakilan, hasLength(1));
      expect(o.durum.birakildi, isTrue);
    },
  );

  test(
    'Bırakma sürerken başka sayfa açılırsa sonuç yine bırakılır, ekran takılmaz',
    () async {
      final o = oturum(secili: kart);
      final yavas = Completer<String>();
      final ara = _YavasBirakma(b, yavas);
      final o2 = DenizPayOturumu(
        baglam: o.baglam,
        tarayici: t,
        adres: koken,
        birakma: ara,
        kartiOku: () async => null,
      );
      t.ozet = sonucSayfasi();
      final ilk = o2.sayfaYuklendi(sayfa('/sonuc.aspx'));
      await Future<void>.delayed(Duration.zero);
      t.ozet = kartSayfasi();
      await o2.sayfaYuklendi(sayfa('/odeme.aspx'));
      yavas.complete('ok');
      await ilk;
      expect(ara.birakilan, hasLength(1));
      expect(o2.durum.sayfa, DenizPaySayfasi.kart);
      expect(o2.durum.mesgul, isFalse);
      expect(o2.durum.kayitNotu, isNull);
    },
  );

  test('Üst üste yüklenen sayfalarda yalnız sonuncusu geçerli', () async {
    final o = oturum(secili: kart);
    final yavas = Completer<Object?>();
    t.bekleyenOzet = yavas;
    final ilk = o.sayfaYuklendi(sayfa('/odeme.aspx'));
    t.bekleyenOzet = null;
    t.ozet = sonucSayfasi();
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    yavas.complete(kartSayfasi());
    await ilk;
    expect(o.durum.sayfa, DenizPaySayfasi.sonuc);
    expect(o.durum.adres, sayfa('/sonuc.aspx'));
  });

  test('Kapanınca oturum silinir, sonraki olaylar yok sayılır', () async {
    final o = oturum();
    final gorulen = <DenizPaySayfasi>[];
    o.durumlar.listen((d) => gorulen.add(d.sayfa));
    await o.kapat();
    await o.kapat();
    expect(t.olaylar, ['temizle']);
    t.ozet = sonucSayfasi();
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    expect(gorulen, isEmpty);
  });
}

class _YavasBirakma implements SonucBirakmaPortu {
  _YavasBirakma(this._b, this._yanit);
  final SahteBirakma _b;
  final Completer<String> _yanit;
  final birakilan = <Map<String, Object?>>[];
  @override
  Future<String> birak(Map<String, Object?> kayit) async {
    birakilan.add(kayit);
    return _yanit.future;
  }

  @override
  Stream<({String kimlik, bool tamam, String mesaj})> get yanitlar =>
      _b.yanitlar;
}
