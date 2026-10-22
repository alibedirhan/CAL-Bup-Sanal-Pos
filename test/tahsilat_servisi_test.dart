import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/application/tahsilat_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/data/demo_islemleri.dart';
import 'package:bup_sanal_pos/domain/acik_giris.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/pos_onayi.dart';
import 'doldurma_test.dart' show SahteDoldurma, girisYap, kasaKarti;
import 'pos_gecisi_test.dart' show SahteGirisKapisi, onayla;

/// Son giriş işaretini bellekte tutar; yazıldığı anda kapının açılıp
/// açılmadığını kaydeder (işaret DenizPay'den önce yazılmalı).
class SahteAcikGiris implements AcikGirisPortu {
  SahteAcikGiris(this.kapi);
  final SahteGirisKapisi kapi;
  final yazilan = <AcikGiris>[];
  final kapiAcikmiydi = <bool>[];
  var temizlenme = 0;
  @override
  bool get destekli => true;
  @override
  void ekle(AcikGiris acik) {
    yazilan.add(acik);
    kapiAcikmiydi.add(kapi.girisler.isNotEmpty);
  }

  @override
  void temizle() => temizlenme++;
}

class KayitliDepo extends DemoIslemDeposu {
  KayitliDepo({super.saat});
  final istenen = <String?>[];
  @override
  Future<GunKayitlari> gun(Gun gun, {String? kullaniciId}) {
    istenen.add(kullaniciId);
    return super.gun(gun, kullaniciId: kullaniciId);
  }
}

/// Yerel sonuç kutusunun bellekteki karşılığı.
class SahteKutu implements SonucKutusu {
  final kayitlar = <Map<String, Object?>>[];
  final yanitlar = <(String, bool, String)>[];
  final _olay = StreamController<void>.broadcast();
  @override
  bool get destekli => true;
  @override
  List<Map<String, Object?>> oku() => List.of(kayitlar);
  @override
  void sil(String no) => kayitlar.removeWhere((k) => k['posSiparisNo'] == no);
  @override
  void yanitla(String no, {required bool tamam, required String mesaj}) =>
      yanitlar.add((no, tamam, mesaj));
  @override
  Stream<void> get degisimler => _olay.stream;
}

/// Sonuç sayfasının bıraktığı kayıt; `v: 1` 0.9.0 biçimidir (eşleşme yok).
Map<String, Object?> bekleyen(
  String no, {
  String uid = 'u1',
  Object? sonuc,
  int v = 2,
  String eslesme = 'kart_sayfasi',
  String cariId = 'demo-cari-0',
  String cariAd = 'Örnek Kuzey Market',
  DateTime? okunma,
}) => {
  'v': v,
  if (v != 1) 'eslesme': eslesme,
  'uid': uid,
  'girisId': 'G' * 20,
  'cariId': cariId,
  'cariAd': cariAd,
  'kimlikNo': '0000000001',
  'kartSonDort': '1111',
  'sonuc': sonuc ?? 'basarili',
  'aciklama': 'Ödeme Başarıyla Gerçekleştirildi',
  'posSiparisNo': no,
  'uyeSiparisNo': '600001',
  'tutarMetni': '4500',
  'okunma': (okunma ?? DateTime.now()).millisecondsSinceEpoch,
};

/// İstenen numarada istenen hatayı veren depo.
class HataliDepo extends DemoIslemDeposu {
  HataliDepo(this.hatalar);
  final Map<String, PosHatasi> hatalar;
  @override
  Future<IslemKaydi> islemKaydet(PosIslemi i) async {
    final h = hatalar[i.posSiparisNo];
    if (h != null) throw h;
    return super.islemKaydet(i);
  }
}

void main() {
  group('Sonuç kutusu', () {
    test(
      'Kendi sonuçları yazılır, silinir, sonuç sayfasına yanıt gider',
      () async {
        final kutu = SahteKutu()
          ..kayitlar.addAll([
            bekleyen('VP9001'),
            bekleyen('VP9002', sonuc: 'hata'),
            bekleyen('VP9003', uid: 'baska'),
            bekleyen('VP9004', sonuc: 'belki'),
          ]);
        final depo = DemoIslemDeposu();
        final servis = TahsilatServisi(
          depo: depo,
          kullaniciId: 'u1',
          kullaniciAdi: 'Örnek Satıcı',
          kutu: kutu,
        );
        final sonuclar = await servis.kutuyuIsle();
        expect(sonuclar.map((s) => s.tamam), [true, true]);
        expect(
          sonuclar.first.mesaj,
          startsWith('Kaydedildi: Örnek Kuzey Market · 4.500,00 TL · başarılı'),
        );
        // Başka hesabın sonucu kalır; bozuk kayıt atılır.
        expect(kutu.kayitlar.map((k) => k['posSiparisNo']), ['VP9003']);
        expect(kutu.yanitlar.map((y) => (y.$1, y.$2)), [
          ('VP9001', true),
          ('VP9002', true),
        ]);
        final gun = await depo.gun(servis.bugun, kullaniciId: 'u1');
        final i = gun.islemler.singleWhere((x) => x.posSiparisNo == 'VP9001');
        expect(i.kaynak, IslemKaynagi.yerImi);
        expect(i.girisId, 'G' * 20);
        expect(i.kullaniciAd, 'Örnek Satıcı');
        expect(i.kartSonDort, '1111');
        // Aynı sonuç yeniden bırakılırsa ikinci kayıt oluşmaz.
        kutu.kayitlar.add(bekleyen('VP9001'));
        final ikinci = await servis.kutuyuIsle();
        expect(ikinci.single.mesaj, startsWith('Bu ödeme zaten kayıtlı'));
        expect(
          (await depo.gun(
            servis.bugun,
            kullaniciId: 'u1',
          )).islemler.where((x) => x.posSiparisNo == 'VP9001'),
          hasLength(1),
        );
      },
    );

    test(
      'Bağlantı yoksa kutuda kalır; kalıcı red elle kontrol ister',
      () async {
        final kutu = SahteKutu()
          ..kayitlar.addAll([bekleyen('VP8001'), bekleyen('VP8002')]);
        final hatalar = {
          'VP8001': const PosHatasi('yetki', 'erişim yok'),
          'VP8002': const PosHatasi('baglanti', 'bağlantı yok'),
        };
        final servis = TahsilatServisi(
          depo: HataliDepo(hatalar),
          kullaniciId: 'u1',
          kullaniciAdi: 'Örnek Satıcı',
          kutu: kutu,
        );
        final s = await servis.kutuyuIsle();
        expect(s.map((x) => x.tamam), [false, false]);
        expect(
          s.first.mesaj,
          contains('Cari sana atanmamış ya da VKN değişmiş'),
        );
        expect(s.last.mesaj, contains('bağlantı gelince'));
        expect(kutu.kayitlar.map((k) => k['posSiparisNo']), ['VP8002']);
        expect(kutu.yanitlar.single.$1, 'VP8001');
        hatalar.clear();
        expect((await servis.kutuyuIsle()).single.tamam, isTrue);
        expect(kutu.kayitlar, isEmpty);
      },
    );

    test(
      'Eşleşme ve okunma kayda geçer; 0.9.0 sonucu son giriş sayılır',
      () async {
        final okunma = DateTime.now().subtract(const Duration(minutes: 3));
        final kutu = SahteKutu()
          ..kayitlar.addAll([
            bekleyen('VP6001', eslesme: 'secim', okunma: okunma),
            bekleyen('VP6002', v: 1),
            bekleyen('VP6003', eslesme: 'elle'), // yer imi elle diyemez
            bekleyen('VP6004', eslesme: 'son_giris'), // yalnız 0.9.0
            bekleyen('VP6005', v: 3),
          ]);
        final depo = DemoIslemDeposu();
        final servis = TahsilatServisi(
          depo: depo,
          kullaniciId: 'u1',
          kullaniciAdi: 'Örnek Satıcı',
          kutu: kutu,
        );
        expect((await servis.kutuyuIsle()).map((s) => s.tamam), [true, true]);
        expect(kutu.kayitlar, isEmpty);
        final l = (await depo.gun(servis.bugun, kullaniciId: 'u1')).islemler;
        PosIslemi no(String n) => l.singleWhere((x) => x.posSiparisNo == n);
        expect(no('VP6001').eslesme, CariEslesmesi.secim);
        expect(
          no('VP6001').okunma!.millisecondsSinceEpoch,
          okunma.millisecondsSinceEpoch,
        );
        expect(no('VP6002').eslesme, CariEslesmesi.sonGiris);
        expect(
          l.where(
            (x) => {'VP6003', 'VP6004', 'VP6005'}.contains(x.posSiparisNo),
          ),
          isEmpty,
        );
      },
    );

    test('Aynı ödeme başka cariye kayıtlıysa "tamam" denmez', () async {
      final kutu = SahteKutu()..kayitlar.add(bekleyen('VP6101'));
      final servis = TahsilatServisi(
        depo: DemoIslemDeposu(),
        kullaniciId: 'u1',
        kullaniciAdi: 'Örnek Satıcı',
        kutu: kutu,
      );
      expect((await servis.kutuyuIsle()).single.tamam, isTrue);
      kutu.kayitlar.add(
        bekleyen('VP6101', cariId: 'demo-cari-1', cariAd: 'Örnek Sahil Gıda'),
      );
      final s = (await servis.kutuyuIsle()).single;
      expect(s.tamam, isFalse);
      expect(s.mesaj, contains('zaten Örnek Kuzey Market carisine kayıtlı'));
      expect(s.mesaj, contains('Seçtiğin Örnek Sahil Gıda değil'));
      expect(kutu.yanitlar.last.$2, isFalse);
      expect(kutu.kayitlar, isEmpty);
    });

    test('Dün okunan sonuç bugün yazılınca gün açıkça söylenir', () async {
      // 22 Ekim 00:05 Türkiye saati; sonuç 21 Ekim 23:58'de okundu.
      final simdi = DateTime.utc(2026, 10, 21, 21, 5);
      final kutu = SahteKutu()
        ..kayitlar.add(
          bekleyen('VP6201', okunma: DateTime.utc(2026, 10, 21, 20, 58)),
        );
      final servis = TahsilatServisi(
        depo: DemoIslemDeposu(saat: () => simdi),
        kullaniciId: 'u1',
        kullaniciAdi: 'Örnek Satıcı',
        kutu: kutu,
        saat: () => simdi,
      );
      expect(
        (await servis.kutuyuIsle()).single.mesaj,
        endsWith(
          'Sonuç 21.10.2026 23:58’de okunmuştu; 22.10.2026 gün sonuna yazıldı.',
        ),
      );
    });

    test('İşlem sürerken gelen yeni sonuç aynı turda yazılır', () async {
      final kutu = SahteKutu()..kayitlar.add(bekleyen('VP7001'));
      final servis = TahsilatServisi(
        depo: DemoIslemDeposu(),
        kullaniciId: 'u1',
        kullaniciAdi: 'Örnek Satıcı',
        kutu: kutu,
      );
      final ilk = servis.kutuyuIsle();
      kutu.kayitlar.add(bekleyen('VP7002'));
      expect(await servis.kutuyuIsle(), isEmpty); // ikinci çağrı beklemez
      expect((await ilk).length, 2);
      expect(kutu.kayitlar, isEmpty);
    });
  });

  testWidgets('Giriş: işaret DenizPay’den önce yazılır, kayıt sunucuya gider', (
    tester,
  ) async {
    final simdi = DateTime.now();
    final kapi = SahteGirisKapisi();
    final acik = SahteAcikGiris(kapi);
    final islemler = DemoIslemDeposu(saat: () => simdi);
    final depo = DemoDeposu();
    final p = await depo.profil(DemoDeposu.kullanici, 'demo-cari-0');
    await depo.kartKaydet(
      DemoDeposu.kullanici,
      'demo-cari-0',
      p.cari.surum,
      kasaKarti(),
    );
    final model = OturumModeli(
      PosServisi(
        depo: depo,
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
        girisKapisi: kapi,
        doldurma: SahteDoldurma(),
        saat: () => simdi,
        tahsilat: TahsilatServisi(
          depo: islemler,
          kullaniciId: DemoDeposu.kullanici,
          kullaniciAdi: 'Örnek Satıcı',
          acikGiris: acik,
          saat: () => simdi,
        ),
      ),
      deneme: false,
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc('demo-cari-0');
    model.kartSec(
      model.profil!.kartlar.singleWhere((k) => k.id == 'kasa-kart'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PosOnayi(model: model)),
      ),
    );
    await tester.pumpAndSettle();
    await onayla(tester);
    await girisYap(tester);

    expect(kapi.girisler, hasLength(1));
    expect(acik.kapiAcikmiydi, [false]);
    final j = acik.yazilan.single.toJson();
    expect(
      j.keys,
      unorderedEquals([
        'v',
        'uid',
        'girisId',
        'cariId',
        'cariAd',
        'kimlikNo',
        'kartSonDort',
        'an',
        'son',
      ]),
    );
    expect(j['v'], 2);
    expect(j['an'], simdi.millisecondsSinceEpoch);
    // Yeni giriş öncekileri silmez (liste); sonuç sayfası doğru girişi seçer.
    expect(acik.temizlenme, 0);
    expect(j['cariId'], 'demo-cari-0');
    expect(j['cariAd'], 'Örnek Kuzey Market');
    expect(j['kimlikNo'], '0000000001');
    expect(j['kartSonDort'], '1111');
    expect(
      j['son'],
      simdi.add(const Duration(hours: 2)).millisecondsSinceEpoch,
    );
    expect(j.toString(), isNot(contains('kasa-referansi')));
    expect(find.textContaining('sonuç bu cariye kaydedilir'), findsOneWidget);

    final gun = await islemler.gun(Gun.ani(simdi));
    expect(gun.girisler.single.id, j['girisId']);
    expect(gun.girisler.single.kullaniciAd, 'Örnek Satıcı');

    // Elle açılan boş giriş sayfası başka cariye ait olabilir: işaret silinir.
    final once = acik.temizlenme;
    model.acikGirisiTemizle();
    expect(acik.temizlenme, once + 1);
  });

  group('Elle kayıt', () {
    late TahsilatServisi servis;
    late Cari cari;
    setUp(() async {
      servis = TahsilatServisi(
        depo: DemoIslemDeposu(),
        kullaniciId: DemoDeposu.kullanici,
        kullaniciAdi: 'Örnek Satıcı',
      );
      cari = (await DemoDeposu().profil(
        DemoDeposu.kullanici,
        'demo-cari-3',
      )).cari;
    });
    Future<IslemKaydi> kaydet({
      String no = 'VP555',
      String tutar = '4500',
      IslemSonucu sonuc = IslemSonucu.basarili,
      String aciklama = '',
      Cari? c,
    }) => servis.elleKaydet(
      cari: c ?? cari,
      sonuc: sonuc,
      posSiparisNo: no,
      tutarMetni: tutar,
      aciklama: aciklama,
    );

    test('Kaydedilir; aynı numara ikinci kez yazılmaz', () async {
      final ilk = await kaydet();
      expect(ilk.zatenVardi, isFalse);
      expect(ilk.islem.kaynak, IslemKaynagi.elle);
      expect(ilk.islem.cariAd, 'Örnek Ada Market');
      expect(ilk.islem.tutarKurus, 450000);
      expect(ilk.islem.kullaniciAd, 'Örnek Satıcı');
      final ikinci = await kaydet(no: ' vp 555', tutar: '1');
      expect(ikinci.zatenVardi, isTrue);
      expect(ikinci.islem.tutarKurus, 450000);
      final g = await servis.gunSonu(servis.bugun);
      expect(
        g.cariler.singleWhere((c) => c.cariId == 'demo-cari-3').islemler,
        hasLength(1),
      );
    });

    test(
      'Belirsiz tutar, eksik hata nedeni ve VKN’siz cari reddedilir',
      () async {
        Future<String> kod(Future<void> f) =>
            f.then((_) => 'yok', onError: (Object e) => (e as PosHatasi).kod);
        expect(await kod(kaydet(tutar: '4,500.00')), 'tutar');
        expect(await kod(kaydet(sonuc: IslemSonucu.hata)), 'aciklama');
        expect(await kod(kaydet(no: 'VP')), 'pos_no');
        expect(await kod(kaydet(c: cari.duzenle(kimlikNo: ''))), 'kimlik');
      },
    );

    test('Başka kullanıcının numarası kullanılamaz', () async {
      final depo = DemoIslemDeposu();
      final baska = TahsilatServisi(
        depo: depo,
        kullaniciId: 'baska',
        kullaniciAdi: 'Başka Satıcı',
      );
      await baska.elleKaydet(
        cari: cari,
        sonuc: IslemSonucu.basarili,
        posSiparisNo: 'VP777',
        tutarMetni: '10',
      );
      servis = TahsilatServisi(
        depo: depo,
        kullaniciId: DemoDeposu.kullanici,
        kullaniciAdi: 'Örnek Satıcı',
      );
      expect(
        () => kaydet(no: 'VP777'),
        throwsA(isA<PosHatasi>().having((e) => e.kod, 'kod', 'pos_no_baska')),
      );
    });
  });

  test('Gelecek gün istenmez; "Herkes" tüm kullanıcıları ister', () async {
    final depo = KayitliDepo();
    final servis = TahsilatServisi(
      depo: depo,
      kullaniciId: 'u1',
      kullaniciAdi: 'Örnek Satıcı',
    );
    expect(
      () => servis.gunSonu(servis.bugun.sonraki),
      throwsA(isA<PosHatasi>()),
    );
    await servis.gunSonu(servis.bugun);
    await servis.gunSonu(servis.bugun.onceki, herkes: true);
    expect(depo.istenen, ['u1', null]);
    // İndirme desteklenmeyen cihazda kullanıcıya açık mesaj verilir.
    final g = await servis.gunSonu(servis.bugun);
    expect(
      () => servis.disaAktar(g),
      throwsA(isA<PosHatasi>().having((e) => e.kod, 'kod', 'indir')),
    );
  });
}
