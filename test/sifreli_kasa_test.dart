import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bup_sanal_pos/data/kasa/sifreli_kasa.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';

/// Gerçek AES-GCM değil: kimlik doğrulamalı şifrelemenin sözleşmesini taklit
/// eder (anahtar kullanıcıya özel, ek veri veya şifreli veri değişirse açılmaz).
/// Gerçek Keystore şifrelemesi emülatördeki Android testlerinde sınanır.
class SahteSifreleyici implements KasaSifreleyici {
  final anahtarlar = <String, int>{};
  final _r = Random(7);
  var uretilen = 0;

  Uint8List _etiket(int anahtar, Uint8List ek, Uint8List iv, List<int> c) {
    var h = 0x811c9dc5 ^ anahtar;
    for (final b in [...ek, 0, ...iv, 0, ...c]) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return Uint8List.fromList(List.generate(16, (i) => (h >> (i % 4 * 8)) ^ i));
  }

  @override
  Future<SifreliVeri> sifrele(
    String uid,
    Uint8List ekVeri,
    Uint8List duz, {
    required bool olustur,
  }) async {
    var a = anahtarlar[uid];
    if (a == null) {
      if (!olustur) throw StateError('anahtar yok');
      a = anahtarlar[uid] = _r.nextInt(1 << 30);
      uretilen++;
    }
    final iv = Uint8List.fromList(List.generate(12, (_) => _r.nextInt(256)));
    final c = [for (var i = 0; i < duz.length; i++) duz[i] ^ ((a + i) & 0xff)];
    return SifreliVeri(
      iv,
      Uint8List.fromList([...c, ..._etiket(a, ekVeri, iv, c)]),
    );
  }

  @override
  Future<Uint8List> coz(String uid, Uint8List ekVeri, SifreliVeri v) async {
    final a = anahtarlar[uid];
    if (a == null) throw StateError('anahtar yok');
    final c = v.veri.sublist(0, v.veri.length - 16);
    final etiket = v.veri.sublist(v.veri.length - 16);
    if (!listEquals(etiket, _etiket(a, ekVeri, v.iv, c))) {
      throw StateError('etiket');
    }
    // Android kanalı gibi salt okunur dizi döner (silme denemesi hata vermemeli).
    return Uint8List.fromList([
      for (var i = 0; i < c.length; i++) c[i] ^ ((a + i) & 0xff),
    ]).asUnmodifiableView();
  }
}

class BellekDeposu implements KasaDeposu {
  final belgeler = <String, String>{};
  var yazma = 0;
  @override
  Future<Map<String, Object?>?> oku(String uid) async {
    final b = belgeler[uid];
    return b == null ? null : (jsonDecode(b) as Map).cast<String, Object?>();
  }

  @override
  Future<void> yaz(String uid, Map<String, Object?> belge) async {
    // Bir sonraki olay turunda: eşzamanlı işlemler gerçekten iç içe geçebilsin.
    await Future<void>.delayed(Duration.zero);
    belgeler[uid] = jsonEncode(belge);
    yazma++;
  }
}

KartOzeti ozet({
  String id = 'k1',
  String cari = 'c1',
  String son = '1111',
  int ay = 12,
  int yil = 2030,
  String? kayit,
}) => KartOzeti(
  id: id,
  cariId: cari,
  ad: 'İş kartı',
  sonDort: son,
  ay: ay,
  yil: yil,
  cihazKayitId: kayit,
);

final visa = KartBilgileri(
  numara: '4111 1111 1111 1111',
  sahibi: 'DENEME KİŞİ',
  telefon: '0532 000 00 00',
);
final master = KartBilgileri(numara: '5555555555554444');

final kasaHatasi = throwsA(
  isA<PosHatasi>().having((e) => e.kod, 'kod', 'cihaz'),
);

void main() {
  late SahteSifreleyici sifre;
  late BellekDeposu depo;
  late SifreliKasa kasa;
  setUp(() {
    sifre = SahteSifreleyici();
    depo = BellekDeposu();
    kasa = SifreliKasa(sifre, depo);
  });

  test('Taslak, tamamlama ve geri okuma; belgede düz kart yok', () async {
    final id = await kasa.hazirla('u1', ozet(), visa);
    await kasa.tamamla('u1', id);
    final b = await kasa.oku('u1', ozet(kayit: id));
    expect(b!.numara, '4111111111111111');
    expect(b.sahibi, 'DENEME KİŞİ');
    expect(b.telefon, '+905320000000');
    final belge = depo.belgeler['u1']!;
    for (final gizli in ['4111111111111111', 'DENEME', '5320000000']) {
      expect(belge.contains(gizli), isFalse, reason: gizli);
    }
    expect(jsonDecode(belge)['taslaklar'], isEmpty);
  });

  test(
    'Referanssız kart, başka kullanıcı ve bilinmeyen referans açılmaz',
    () async {
      final id = await kasa.hazirla('u1', ozet(), visa);
      await kasa.tamamla('u1', id);
      expect(await kasa.oku('u1', ozet()), isNull);
      expect(await kasa.oku('u2', ozet(kayit: id)), isNull);
      expect(await kasa.oku('u1', ozet(kayit: 'baska')), isNull);
    },
  );

  test(
    'Son yerel adımı yarım kalan kart sunucu referansıyla kurtarılır',
    () async {
      final id = await kasa.hazirla('u1', ozet(), visa);
      // tamamla çağrılmadı (ör. uygulama kapandı); sunucu referansı biliyor.
      expect((await kasa.oku('u1', ozet(kayit: id)))!.numara, visa.numara);
      final belge = jsonDecode(depo.belgeler['u1']!) as Map;
      expect(belge['taslaklar'], isEmpty);
      expect((belge['kartlar'] as Map).length, 1);
    },
  );

  test('Yeni taslak, onaylanana kadar eski etkin kaydı değiştirmez', () async {
    final eski = await kasa.hazirla('u1', ozet(son: '4444'), master);
    await kasa.tamamla('u1', eski);
    final yeni = await kasa.hazirla('u1', ozet(), visa);
    expect(
      (await kasa.oku('u1', ozet(son: '4444', kayit: eski)))!.numara,
      master.numara,
    );
    await kasa.tamamla('u1', yeni);
    expect((await kasa.oku('u1', ozet(kayit: yeni)))!.numara, visa.numara);
    // Eski referans artık hiçbir kayda karşılık gelmez.
    expect(await kasa.oku('u1', ozet(son: '4444', kayit: eski)), isNull);
  });

  test(
    'Özet (tarih/son dört) değişirse şifre çözülmez, kayıt silinmez',
    () async {
      final id = await kasa.hazirla('u1', ozet(), visa);
      await kasa.tamamla('u1', id);
      final once = depo.belgeler['u1'];
      await expectLater(kasa.oku('u1', ozet(ay: 11, kayit: id)), kasaHatasi);
      await expectLater(kasa.oku('u1', ozet(yil: 2031, kayit: id)), kasaHatasi);
      expect(depo.belgeler['u1'], once);
      expect((await kasa.oku('u1', ozet(kayit: id)))!.numara, visa.numara);
    },
  );

  test(
    'Kurcalanmış şifreli veri, IV veya başka hesabın belgesi reddedilir',
    () async {
      final id = await kasa.hazirla('u1', ozet(), visa);
      await kasa.tamamla('u1', id);
      final asil = depo.belgeler['u1']!;
      Map<String, Object?> kayit(Map b) =>
          ((b['kartlar'] as Map).values.single as Map).cast();

      for (final alan in ['veri', 'iv']) {
        final b = jsonDecode(asil) as Map;
        final baytlar = base64.decode(kayit(b)[alan] as String);
        baytlar[0] ^= 1;
        kayit(b)[alan] = base64.encode(baytlar);
        depo.belgeler['u1'] = jsonEncode(b);
        await expectLater(kasa.oku('u1', ozet(kayit: id)), kasaHatasi);
      }
      // Kayıttaki açık alanlar (tarih, son dört) özete uyacak şekilde
      // değiştirilse de ek doğrulama verisi şifre çözmeyi engeller.
      for (final (alan, deger, kart) in [
        ('ay', 11, ozet(ay: 11, kayit: id)),
        ('yil', 2031, ozet(yil: 2031, kayit: id)),
      ]) {
        final b = jsonDecode(asil) as Map;
        kayit(b)[alan] = deger;
        depo.belgeler['u1'] = jsonEncode(b);
        await expectLater(kasa.oku('u1', kart), kasaHatasi);
      }
      // u1'in belgesi u2'nin yerine kopyalanır.
      depo.belgeler['u2'] = asil;
      sifre.anahtarlar['u2'] = sifre.anahtarlar['u1']!;
      await expectLater(kasa.oku('u2', ozet(kayit: id)), kasaHatasi);
      await expectLater(kasa.hazirla('u2', ozet(), visa), kasaHatasi);
      expect(depo.belgeler['u2'], asil);
    },
  );

  test('Bozuk belge sessizce sıfırlanmaz', () async {
    depo.belgeler['u1'] = '{"v":1,"uid":"u1","kartlar":[],"taslaklar":{}}';
    await expectLater(kasa.hazirla('u1', ozet(), visa), kasaHatasi);
    await expectLater(kasa.sil('u1', 'c1', null), kasaHatasi);
    expect(depo.yazma, 0);
  });

  test(
    'Kasada kayıt varken anahtar kaybolursa yeni anahtar üretilmez',
    () async {
      final id = await kasa.hazirla('u1', ozet(), visa);
      await kasa.tamamla('u1', id);
      sifre.anahtarlar.clear();
      await expectLater(kasa.hazirla('u1', ozet(id: 'k2'), visa), kasaHatasi);
      expect(sifre.uretilen, 1);
      // Kayıtlar silinince (kişi kartı sildi) yeni anahtar üretilebilir.
      await kasa.sil('u1', 'c1', null);
      await kasa.hazirla('u1', ozet(id: 'k2'), visa);
      expect(sifre.uretilen, 2);
    },
  );

  test(
    'Silme yalnız istenen kartı veya carinin bütün kartlarını kaldırır',
    () async {
      Future<String> ekle(
        String kart,
        String cari,
        KartBilgileri b,
        String son,
      ) async {
        final id = await kasa.hazirla(
          'u1',
          ozet(id: kart, cari: cari, son: son),
          b,
        );
        await kasa.tamamla('u1', id);
        return id;
      }

      final a = await ekle('k1', 'c1', visa, '1111');
      final b = await ekle('k2', 'c1', master, '4444');
      final c = await ekle('k1', 'c2', visa, '1111');
      final taslak = await kasa.hazirla('u1', ozet(id: 'k3'), visa);
      await kasa.sil('u1', 'c1', 'k1');
      expect(await kasa.oku('u1', ozet(kayit: a)), isNull);
      expect(
        await kasa.oku('u1', ozet(id: 'k2', son: '4444', kayit: b)),
        isNotNull,
      );
      await kasa.sil('u1', 'c1', null);
      expect(
        await kasa.oku('u1', ozet(id: 'k2', son: '4444', kayit: b)),
        isNull,
      );
      expect(await kasa.oku('u1', ozet(id: 'k3', kayit: taslak)), isNull);
      expect(await kasa.oku('u1', ozet(cari: 'c2', kayit: c)), isNotNull);
      await kasa.sil('u9', 'c1', null);
    },
  );

  test('Eşzamanlı işlemler birbirini ezmez', () async {
    final ids = await Future.wait([
      for (var i = 0; i < 6; i++) kasa.hazirla('u1', ozet(id: 'k$i'), visa),
    ]);
    await Future.wait([for (final id in ids) kasa.tamamla('u1', id)]);
    for (var i = 0; i < 6; i++) {
      expect(await kasa.oku('u1', ozet(id: 'k$i', kayit: ids[i])), isNotNull);
    }
    expect(sifre.uretilen, 1);
  });

  test(
    'Geçersiz kapsam, eşleşmeyen kart ve bilinmeyen taslak reddedilir',
    () async {
      await expectLater(kasa.hazirla('', ozet(), visa), kasaHatasi);
      await expectLater(
        kasa.hazirla('u1', ozet(son: '4444'), visa),
        kasaHatasi,
      );
      await expectLater(kasa.tamamla('u1', 'yok'), kasaHatasi);
      expect(depo.yazma, 0);
      // Hata sonrası sıra kilitlenmez.
      final id = await kasa.hazirla('u1', ozet(), visa);
      await kasa.tamamla('u1', id);
    },
  );
}
