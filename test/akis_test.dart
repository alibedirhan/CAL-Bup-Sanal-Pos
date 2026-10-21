import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/portlar.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';

class BekleyenBaglanti implements PosBaglantisi {
  final tamam = Completer<DenemeSonucu>();
  final basladi = Completer<void>();
  int cagri = 0;
  @override
  Future<DenemeSonucu> dene(Cari cari, KartOzeti kart) {
    cagri++;
    if (!basladi.isCompleted) basladi.complete();
    return tamam.future;
  }
}

void main() {
  late DemoDeposu depo;
  late PosServisi servis;
  const secim = PosSecimi(
    cariId: 'demo-cari-0',
    cariSurumu: 1,
    kartId: 'demo-kart-0',
  );
  setUp(() {
    depo = DemoDeposu(simdi: DateTime(2026, 10));
    servis = PosServisi(
      depo: depo,
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      saat: () => DateTime(2026, 10, 18),
    );
  });
  test('Geçiş yalnız seçili carinin güncel kartıyla denenebilir', () async {
    final sonuc = await servis.dene(secim, oturumAcik: () => true);
    expect(sonuc.kartSonDort, '0001');
    await expectLater(
      servis.dene(
        const PosSecimi(
          cariId: 'demo-cari-0',
          cariSurumu: 1,
          kartId: 'demo-kart-1',
        ),
        oturumAcik: () => true,
      ),
      throwsA(isA<PosHatasi>()),
    );
  });
  test('Süresi dolan kart geçiş başlatmaz', () async {
    await expectLater(
      servis.dene(
        const PosSecimi(
          cariId: 'demo-cari-1',
          cariSurumu: 1,
          kartId: 'demo-gecmis-kart',
        ),
        oturumAcik: () => true,
      ),
      throwsA(isA<PosHatasi>()),
    );
  });
  test('Onaydan sonra değişen veya silinen cari kullanılmaz', () async {
    final cari = (await servis.profil(secim.cariId)).cari;
    await servis.kaydet(cari.duzenle(ad: 'Değişen Ad'), 1);
    await expectLater(
      servis.dene(secim, oturumAcik: () => true),
      throwsA(isA<PosHatasi>()),
    );
    await servis.sil((await servis.profil(secim.cariId)).cari);
    await expectLater(
      servis.dene(secim, oturumAcik: () => true),
      throwsA(isA<PosHatasi>()),
    );
  });
  test('Çift dokunuş tek bağlantı çağrısı yapar', () async {
    final b = BekleyenBaglanti();
    final s = PosServisi(
      depo: depo,
      baglanti: b,
      kullaniciId: DemoDeposu.kullanici,
      saat: () => DateTime(2026, 10),
    );
    final ilk = s.dene(secim, oturumAcik: () => true);
    await b.basladi.future;
    await expectLater(
      s.dene(secim, oturumAcik: () => true),
      throwsA(isA<PosHatasi>()),
    );
    b.tamam.complete(const DenemeSonucu('Örnek', '0001'));
    await ilk;
    expect(b.cagri, 1);
  });
  test('Kilitlenince geciken sonuç ekrana geri dönmez', () async {
    final b = BekleyenBaglanti();
    final model = OturumModeli(
      PosServisi(
        depo: depo,
        baglanti: b,
        kullaniciId: DemoDeposu.kullanici,
        saat: () => DateTime(2026, 10),
      ),
    );
    addTearDown(model.dispose);
    await model.yukle();
    await model.profilAc(secim.cariId);
    model.kartSec(model.profil!.kartlar.first);
    final islem = model.dene();
    await b.basladi.future;
    model.kilitle();
    model.denemeyeDon();
    b.tamam.complete(const DenemeSonucu('Örnek', '0001'));
    expect(await islem, isNull);
    expect(model.profil, isNull);
    expect(model.seciliKart, isNull);
    expect(model.mesgul, isFalse);
  });
  test('Kapalı üretim adaptörü deneme başarısı döndürmez', () async {
    final p = await servis.profil(secim.cariId);
    await expectLater(
      KapaliPosBaglantisi().dene(p.cari, p.kartlar.first),
      throwsA(isA<PosHatasi>()),
    );
  });
}
