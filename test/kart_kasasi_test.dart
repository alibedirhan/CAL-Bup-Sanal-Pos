import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/kart_kasasi.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/data/firestore_esleme.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';

class YapayKasa implements KartKasasi {
  final taslaklar = <String, KartBilgileri>{},
      aktif = <String, KartBilgileri>{};
  bool sonAdimHatasi = false;
  int okuma = 0;
  @override
  Future<String> hazirla(String uid, KartOzeti k, KartBilgileri b) async {
    final id = 'yapay-${taslaklar.length}';
    taslaklar[id] = b;
    return id;
  }

  @override
  Future<void> tamamla(String uid, String id) async {
    if (sonAdimHatasi) throw StateError('Yapay cihaz hatası');
    aktif[id] = taslaklar[id]!;
  }

  @override
  Future<KartBilgileri?> oku(String uid, KartOzeti k) async {
    okuma++;
    return aktif[k.cihazKayitId] ?? taslaklar[k.cihazKayitId];
  }

  @override
  Future<void> sil(String uid, String cariId, String? kartId) async {
    aktif.clear();
    taslaklar.clear();
  }
}

class YazmayanDepo extends DemoDeposu {
  bool reddet = false;
  @override
  Future<void> kartKaydet(
    String uid,
    String id,
    int surum,
    KartOzeti kart,
  ) async {
    if (reddet) throw const PosHatasi('surum', 'Yapay çakışma');
    return super.kartKaydet(uid, id, surum, kart);
  }
}

final yapayBilgi = KartBilgileri(
  numara: '4111 1111 1111 1111',
  sahibi: 'Örnek Kart Sahibi',
);
KartOzeti ozet(String id) => KartOzeti(
  id: 'yapay-yeni',
  cariId: id,
  ad: 'Örnek Kart',
  sonDort: '1111',
  ay: 12,
  yil: 2030,
);
void main() {
  test(
    'Numara ve telefon biçimleri doğrulanır; hata hassas değeri içermez',
    () {
      expect(yapayBilgi.sonDort, '1111');
      expect(kartTelefonu('0500 000 00 00'), '+905000000000');
      expect(kartTelefonu(''), isEmpty);
      for (final n in [
        '4111111111111112',
        '0' * 16,
        '411111111111abcd',
        '4' * 33,
      ]) {
        try {
          kartNumarasi(n);
          fail('Geçersiz numara kabul edildi');
        } on PosHatasi catch (e) {
          expect(e.mesaj.contains(n), isFalse);
        }
      }
      expect(() => kartTelefonu('yapay-telefon'), throwsA(isA<PosHatasi>()));
    },
  );
  test('Yerel kartın yalnız maskeli özeti sunucuya yazılır', () async {
    final depo = DemoDeposu(), kasa = YapayKasa();
    final servis = PosServisi(
      depo: depo,
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      kartKasasi: kasa,
    );
    final c = (await servis.profil('demo-cari-0')).cari;
    final r = await servis.kartKaydet(c, ozet(c.id), bilgiler: yapayBilgi);
    final map = kartYaz(r.kart);
    expect(
      map.keys,
      unorderedEquals(['id', 'ad', 'sonDort', 'ay', 'yil', 'cihazKayitId']),
    );
    expect(map.values.contains(yapayBilgi.numara), isFalse);
    expect(await servis.kartBilgileri(r.kart, () => true), same(yapayBilgi));
    expect(
      (await servis.profil(c.id)).kartlar.last.cihazKayitId,
      r.kart.cihazKayitId,
    );
  });
  test('Sunucu reddederse önceki yerel kayıt değiştirilmez', () async {
    final depo = YazmayanDepo(), kasa = YapayKasa();
    final servis = PosServisi(
      depo: depo,
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      kartKasasi: kasa,
    );
    final c = (await servis.profil('demo-cari-0')).cari;
    final r = await servis.kartKaydet(c, ozet(c.id), bilgiler: yapayBilgi);
    depo.reddet = true;
    await expectLater(
      servis.kartKaydet(c.duzenle(), r.kart, bilgiler: yapayBilgi),
      throwsA(isA<PosHatasi>()),
    );
    expect(kasa.aktif.length, 1);
    expect(
      (await servis.profil(c.id)).kartlar.last.cihazKayitId,
      r.kart.cihazKayitId,
    );
  });
  test(
    'Son yerel adım aksarsa onaylanmış sunucu yazması başarısız gösterilmez',
    () async {
      final depo = DemoDeposu(), kasa = YapayKasa()..sonAdimHatasi = true;
      final servis = PosServisi(
        depo: depo,
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
        kartKasasi: kasa,
      );
      final c = (await servis.profil('demo-cari-0')).cari;
      final r = await servis.kartKaydet(c, ozet(c.id), bilgiler: yapayBilgi);
      expect(r.uyari, contains('Kart kaydedildi'));
      expect(await servis.kartBilgileri(r.kart, () => true), same(yapayBilgi));
    },
  );
  test('Silinmiş/değişmiş kart ve kilit yerel açık bilgiyi okutmaz', () async {
    final depo = DemoDeposu(), kasa = YapayKasa();
    final servis = PosServisi(
      depo: depo,
      baglanti: DemoPosBaglantisi(),
      kullaniciId: DemoDeposu.kullanici,
      kartKasasi: kasa,
    );
    final c = (await servis.profil('demo-cari-0')).cari;
    final r = await servis.kartKaydet(c, ozet(c.id), bilgiler: yapayBilgi);
    await expectLater(
      servis.kartBilgileri(r.kart, () => false),
      throwsA(isA<PosHatasi>()),
    );
    await expectLater(
      servis.kartBilgileri(r.kart.cihazKaydiyla('degismis'), () => true),
      throwsA(isA<PosHatasi>()),
    );
    expect(kasa.okuma, 0);
    await servis.kartSil(c.duzenle(), r.kart.id);
    await expectLater(
      servis.kartBilgileri(r.kart, () => true),
      throwsA(isA<PosHatasi>()),
    );
    expect(kasa.aktif, isEmpty);
  });
}
