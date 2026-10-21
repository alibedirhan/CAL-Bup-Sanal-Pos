import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';

void main() {
  test('Türkçe aramada İ, I, ı ve aksanlar bulunur', () {
    final cari = Cari(
      id: '1',
      sahipId: 'u',
      ad: 'İZMİR IŞIK GIDA',
      kod: 'OR-001',
      kimlikNo: '0000000100',
    );
    expect(cari.eslesir('izmir isik'), isTrue);
    expect(cari.eslesir('ışık'), isTrue);
    expect(cari.eslesir('0000000100'), isTrue);
    expect(cari.eslesir('or-001'), isFalse);
    expect(cari.eslesir('başka'), isFalse);
  });
  test('Cari adı ve kontrol karakterleri doğrulanır', () {
    for (final ad in ['', 'A', 'Gizli\u202Ead', 'A' * 81]) {
      expect(
        () => Cari(id: '1', sahipId: 'u', ad: ad, kod: 'OR-001'),
        throwsA(isA<PosHatasi>()),
      );
    }
  });
  test('Cari kopyası sürümü artırır ve sahipliği korur', () {
    final ilk = Cari(id: '1', sahipId: 'u', ad: 'Örnek Cari', kod: 'OR-001');
    final yeni = ilk.duzenle(ad: 'Yeni Ad');
    expect(yeni.surum, 2);
    expect(yeni.sahipId, ilk.sahipId);
    expect(ilk.ad, 'Örnek Cari');
  });
  test('Kart ayın sonuna kadar kullanılabilir; sonraki ay dolar', () {
    final kart = KartOzeti(
      id: 'k',
      cariId: 'c',
      ad: 'İş kartı',
      sonDort: '0001',
      ay: 10,
      yil: 2026,
    );
    expect(kart.suresiGecti(DateTime(2026, 10, 31, 23, 59)), isFalse);
    expect(kart.suresiGecti(DateTime(2026, 11)), isTrue);
    expect(kart.maske, '••••  0001');
  });
  test('Kart özeti tam numara, bozuk ay ve yıl kabul etmez', () {
    for (final d in [
      ('1234567890123456', 1, 2026),
      ('abcd', 1, 2026),
      ('0001', 0, 2026),
      ('0001', 13, 2026),
      ('0001', 1, 999),
    ]) {
      expect(
        () => KartOzeti(
          id: 'k',
          cariId: 'c',
          ad: 'İş kartı',
          sonDort: d.$1,
          ay: d.$2,
          yil: d.$3,
        ),
        throwsA(isA<PosHatasi>()),
      );
    }
  });
  test('Profil kart listesi dışarıdan değiştirilemez', () {
    final liste = <KartOzeti>[];
    final profil = CariProfili(
      Cari(id: 'c', sahipId: 'u', ad: 'Örnek Cari', kod: 'A'),
      liste,
    );
    liste.add(
      KartOzeti(
        id: 'k',
        cariId: 'c',
        ad: 'Kart',
        sonDort: '0001',
        ay: 12,
        yil: 2030,
      ),
    );
    expect(profil.kartlar, isEmpty);
    expect(() => profil.kartlar.add(liste.first), throwsUnsupportedError);
  });
}
