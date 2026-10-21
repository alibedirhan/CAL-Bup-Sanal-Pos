import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/portlar.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/data/firestore_esleme.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/domain/pos_girisi.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/pos_giris_bilgileri.dart';

// Yazma başarılı; bunu takip eden ayrı bir sunucu okuması gecikiyor.
class OkumasiGecikenDepo extends DemoDeposu {
  bool yazildi = false;
  int eklemeSayisi = 0;
  @override
  Future<List<CariOzeti>> listele(String kullaniciId) async {
    if (yazildi) throw TimeoutException('Yapay okuma gecikmesi');
    return super.listele(kullaniciId);
  }

  @override
  Future<Cari> ekle(
    String uid,
    String ad,
    String kod, {
    String kimlikNo = '',
  }) async {
    final c = await super.ekle(uid, ad, kod, kimlikNo: kimlikNo);
    eklemeSayisi++;
    yazildi = true;
    return c;
  }
}

class IzlemeliDepo extends DemoDeposu implements CariIzlemePortu {
  final akis = StreamController<List<CariOzeti>>();
  final onay = Completer<void>();
  @override
  Stream<List<CariOzeti>> izle(String kullaniciId) => akis.stream;
  @override
  Future<Cari> ekle(
    String uid,
    String ad,
    String kod, {
    String kimlikNo = '',
  }) async {
    final c = await super.ekle(uid, ad, kod, kimlikNo: kimlikNo);
    await onay.future;
    return c;
  }
}

void main() {
  test('Eski cari kodu kullanıcıya sorulmadan kayıt düzenlenebilir', () async {
    final depo = DemoDeposu();
    final model = OturumModeli(
      PosServisi(
        depo: depo,
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
      ),
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc('demo-cari-0');
    final eski = model.profil!;
    expect(
      await model.cariKaydet(
        'Örnek Yeni Ad',
        eski: eski.cari,
        kimlikNo: eski.cari.kimlikNo,
      ),
      isTrue,
    );
    expect(model.profil!.cari.kod, eski.cari.kod);
    expect(model.profil!.kartlar.length, eski.kartlar.length);
  });
  test('Eski şemadaki kayıt kimlik numarasıyla okunur', () {
    final p = cariOku('yapay-eski', {
      'sahipId': 'yapay-kullanici',
      'ad': 'Örnek Eski Cari',
      'kod': 'ESKI-01',
      'yildizli': false,
      'surum': 1,
      'kimlikNo': '0000000100',
      'silindi': false,
      'kartlar': <dynamic>[],
    });
    expect(p.cari.kimlikNo, '0000000100');
    expect(p.cari.eslesir('0000000100'), isTrue);
  });
  test(
    'Onaylanmış cari ayrı okuma gecikse de başarılı ve tek kayıt kalır',
    () async {
      final depo = OkumasiGecikenDepo();
      final model = OturumModeli(
        PosServisi(
          depo: depo,
          baglanti: DemoPosBaglantisi(),
          kullaniciId: DemoDeposu.kullanici,
        ),
      );
      addTearDown(model.dispose);
      await model.yukle();
      expect(
        await model.cariKaydet('Örnek Yeni Cari', kimlikNo: '0000000100'),
        isTrue,
      );
      expect(model.hata, isNull);
      expect(model.profil!.cari.kimlikNo, '0000000100');
      expect(model.profil!.kartlar, isEmpty);
      expect(
        await model.cariKaydet('Örnek Yeni Cari', kimlikNo: '0000000100'),
        isFalse,
      );
      expect(depo.eklemeSayisi, 1);
      expect(model.hata, contains('zaten kayıtlı'));
      final kart = KartOzeti(
        id: 'yapay-kart',
        cariId: model.profil!.cari.id,
        ad: 'Örnek Kart',
        sonDort: '0010',
        ay: 12,
        yil: 2030,
      );
      expect(await model.kartKaydet(kart), isTrue);
      expect(model.profil!.kartlar.single.id, kart.id);
      expect(
        await model.cariKaydet(
          'Örnek Yeni Ad',
          eski: model.profil!.cari,
          kimlikNo: '0000000100',
        ),
        isTrue,
      );
      expect(model.profil!.kartlar.single.id, kart.id);
      expect(await model.yildizla(model.profil!.cari), isTrue);
      expect(model.profil!.cari.yildizli, isTrue);
      expect(await model.kartSil(kart.id), isTrue);
      expect(model.profil!.kartlar, isEmpty);
      expect(await model.cariSil(model.profil!.cari), isTrue);
      expect(model.profil, isNull);
    },
  );
  test('Zaman aşımı veri bozukluğu olarak gösterilmez', () {
    expect(bulutHatasi(TimeoutException('Yapay')).kod, 'baglanti');
    expect(
      bulutHatasi(TimeoutException('Yapay')).mesaj,
      contains('yapılmış olabilir'),
    );
  });
  test('POS şifresi ilk iki ve son iki hanedir; baştaki sıfırlar korunur', () {
    expect(posGirisSifresi('0123456789'), '0189');
    expect(posGirisSifresi('01234567890'), '0190');
    for (final gecersiz in ['', '123', '012345678x', '012345678901']) {
      expect(() => posGirisSifresi(gecersiz), throwsA(isA<PosHatasi>()));
    }
  });
  for (final kod in ['baglanti', 'yetki']) {
    test(
      'Yazma sırasında $kod olayı ve geç sunucu yanıtı güvenli işlenir',
      () async {
        final depo = IzlemeliDepo();
        final model = OturumModeli(
          PosServisi(
            depo: depo,
            baglanti: DemoPosBaglantisi(),
            kullaniciId: DemoDeposu.kullanici,
          ),
          deneme: false,
        );
        addTearDown(() async {
          model.dispose();
          await depo.akis.close();
        });
        await model.yukle();
        final islem = model.cariKaydet(
          'Örnek Yeni Cari',
          kimlikNo: '0000000100',
        );
        await Future<void>.delayed(Duration.zero);
        depo.akis.addError(PosHatasi(kod, 'Yapay olay'));
        await Future<void>.delayed(Duration.zero);
        depo.onay.complete();
        expect(await islem, kod == 'baglanti');
        if (kod == 'yetki') {
          expect(model.cariler, isEmpty);
          expect(model.profil, isNull);
        }
      },
    );
  }
  testWidgets('POS şifresi yalnız açık kopyalama isteğinde panoya yazılır', (
    t,
  ) async {
    final yazilanlar = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          yazilanlar.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PosGirisBilgileri(kimlikNo: '0123456789')),
      ),
    );
    expect(yazilanlar, isEmpty);
    expect(find.text('0189'), findsNothing);
    await t.tap(find.text('POS şifresini kopyala'));
    await t.pumpAndSettle();
    expect(yazilanlar, ['0189']);
    expect(find.text('POS şifresi kopyalandı.'), findsOneWidget);
  });
}
