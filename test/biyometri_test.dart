import 'package:bup_sanal_pos/domain/biyometri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sifre = DateTime.utc(2026, 10, 27, 9);
  final kayit = BiyometriKaydi(uid: 'u1', sonSifre: sifre, acilis: 41);
  bool gecerli({
    String uid = 'u1',
    Duration sonra = Duration.zero,
    int acilis = 41,
  }) => kayit.gecerli(uid: uid, simdi: sifre.add(sonra), acilis: acilis);

  test('Şifreden sonra 7 gün içinde ve aynı açılışta biyometri geçerli', () {
    expect(gecerli(), isTrue);
    expect(gecerli(sonra: const Duration(days: 6, hours: 23)), isTrue);
  });

  test(
    '7 gün dolunca, saat geri alınınca, yeniden başlatmada ve başka hesapta şifre',
    () {
      expect(gecerli(sonra: const Duration(days: 7)), isFalse);
      expect(gecerli(sonra: const Duration(seconds: -1)), isFalse);
      expect(gecerli(acilis: 42), isFalse);
      expect(gecerli(uid: 'u2'), isFalse);
    },
  );

  test(
    'Kayıt yalnız tam ve doğru biçimde okunur; bozuksa biyometri kapalı',
    () {
      final json = kayit.toJson();
      final geri = BiyometriKaydi.fromJson(json)!;
      expect(
        [geri.uid, geri.sonSifre.millisecondsSinceEpoch, geri.acilis],
        ['u1', sifre.millisecondsSinceEpoch, 41],
      );
      for (final bozuk in <Object?>[
        null,
        'metin',
        {...json, 'v': 2},
        {...json, 'uid': ''},
        {...json, 'acilis': '41'},
        {...json, 'fazla': 1},
        Map.of(json)..remove('sonSifre'),
      ]) {
        expect(BiyometriKaydi.fromJson(bozuk), isNull, reason: '$bozuk');
      }
    },
  );
}
