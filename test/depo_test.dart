import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';

void main() {
  late DemoDeposu depo;
  const u = DemoDeposu.kullanici;
  setUp(() => depo = DemoDeposu(simdi: DateTime(2026, 10)));
  test('Liste yalnız kullanıcıya atanmış carileri içerir', () async {
    final liste = await depo.listele(u);
    expect(liste.length, 6);
    expect(liste.every((c) => c.cari.sahipId == u), isTrue);
    expect(await depo.listele('bilinmeyen'), isEmpty);
  });
  test('Başkasının kaydı doğrudan kimlikle okunamaz ve silinemez', () async {
    await expectLater(depo.profil(u, 'baska-cari'), throwsA(isA<PosHatasi>()));
    await expectLater(depo.sil(u, 'baska-cari', 1), throwsA(isA<PosHatasi>()));
    await expectLater(
      depo.denemeKartiEkle(u, 'baska-cari'),
      throwsA(isA<PosHatasi>()),
    );
  });
  test('Sahiplik değişikliği ve eski sürümle yazma reddedilir', () async {
    final eski = (await depo.profil(u, 'demo-cari-0')).cari;
    final sahte = Cari(
      id: eski.id,
      sahipId: 'baska',
      ad: eski.ad,
      kod: eski.kod,
      surum: 2,
    );
    await expectLater(depo.kaydet(u, sahte, 1), throwsA(isA<PosHatasi>()));
    await depo.kaydet(u, eski.duzenle(ad: 'Güncel Ad'), 1);
    await expectLater(
      depo.kaydet(u, eski.duzenle(ad: 'Eski Ad'), 1),
      throwsA(isA<PosHatasi>()),
    );
    expect((await depo.profil(u, eski.id)).cari.ad, 'Güncel Ad');
  });
  test('Aynı kod ikinci kez ve düzenlemede başka cariye yazılamaz', () async {
    await expectLater(
      depo.ekle(u, 'Örnek Yeni Cari', 'or-001'),
      throwsA(isA<PosHatasi>()),
    );
    final c = (await depo.profil(u, 'demo-cari-1')).cari;
    await expectLater(
      depo.kaydet(u, c.duzenle(kod: 'OR-001'), c.surum),
      throwsA(isA<PosHatasi>()),
    );
  });
  test('Silme cariyle birlikte bağlı kartları kaldırır', () async {
    final c = (await depo.profil(u, 'demo-cari-0')).cari;
    await depo.sil(u, c.id, c.surum);
    expect((await depo.listele(u)).length, 5);
    await expectLater(depo.profil(u, c.id), throwsA(isA<PosHatasi>()));
  });
  test('Yeni depo eski oturum değişikliklerini taşımaz', () async {
    await depo.ekle(u, 'Örnek Yeni Cari', 'YENI');
    expect((await depo.listele(u)).length, 7);
    expect((await DemoDeposu().listele(u)).length, 6);
  });
  test('Kart ekleme sınırı 10; aşım mevcut kaydı bozmaz', () async {
    for (var i = 0; i < 8; i++) {
      await depo.denemeKartiEkle(u, 'demo-cari-0');
    }
    await expectLater(
      depo.denemeKartiEkle(u, 'demo-cari-0'),
      throwsA(isA<PosHatasi>()),
    );
    expect((await depo.profil(u, 'demo-cari-0')).kartlar.length, 10);
  });
}
