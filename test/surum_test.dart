import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';
import 'package:bup_sanal_pos/app.dart';
import 'package:bup_sanal_pos/application/surum_denetimi.dart';
import 'package:bup_sanal_pos/domain/surum.dart';
import 'dart:io';
import 'package:bup_sanal_pos/ui/guncelleme.dart';
import 'package:bup_sanal_pos/ui/ortak.dart';

Map<String, Object?> belge([Map<String, Object?> degisen = const {}]) => {
  'enDusuk': 19,
  'son': 21,
  'sonAd': '0.11.2',
  'indirme': 'https://indir.example.test/',
  'sha256': 'ab' * 32,
  ...degisen,
};

class _Surum implements UygulamaSurumuPortu {
  _Surum(this.deger);
  final Future<int?> Function() deger;
  @override
  Future<int?> kod() => deger();
}

class _Ayar implements SurumAyariPortu {
  _Ayar(this.deger);
  final Future<Object?> Function() deger;
  int okuma = 0;
  @override
  Future<Object?> oku() {
    okuma++;
    return deger();
  }
}

void main() {
  test('Ekrandaki sürüm pubspec.yaml sürümüyle aynı', () {
    final satir = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((s) => s.startsWith('version: '));
    expect(satir, startsWith('version: $surumAdi+'));
  });

  test('Belge yalnız tam ve tutarlıysa okunur', () {
    final b = AndroidSurumu.coz(belge())!;
    expect(
      (b.enDusuk, b.son, b.sonAd, b.indirme.host),
      (19, 21, '0.11.2', 'indir.example.test'),
    );
    for (final bozuk in <Object?>[
      null,
      'metin',
      {...belge(), 'fazla': 1},
      belge({'enDusuk': 0}),
      belge({'enDusuk': 22}),
      belge({'son': '21'}),
      belge({'sonAd': '0.11'}),
      belge({'sonAd': '0.11.2 '}),
      belge({'sha256': 'AB' * 32}),
      belge({'sha256': 'ab' * 31}),
      belge({'indirme': 'http://indir.example.test/'}),
      belge({'indirme': 'https://kisi@indir.example.test/'}),
      belge({'indirme': 'https://indir.example.test:8443/'}),
      belge({'indirme': 'intent://indir'}),
      belge({'indirme': 'https:///yol'}),
      belge({'indirme': 'https://${'a' * 300}.test/'}),
    ]) {
      expect(AndroidSurumu.coz(bozuk), isNull, reason: '$bozuk');
    }
  });

  test('Karar: en düşüğün altı gerekli, son altı not, yoksa güncel', () {
    final b = AndroidSurumu.coz(belge())!;
    expect(SurumSonucu.karar(18, b).durum, SurumDurumu.guncellemeGerekli);
    expect(SurumSonucu.karar(19, b).durum, SurumDurumu.guncellemeVar);
    expect(SurumSonucu.karar(20, b).durum, SurumDurumu.guncellemeVar);
    expect(SurumSonucu.karar(21, b).durum, SurumDurumu.guncel);
    expect(SurumSonucu.karar(25, b).durum, SurumDurumu.guncel);
    expect(SurumSonucu.karar(1, null).durum, SurumDurumu.guncel);
  });

  group('Denetim uygulamayı yalnız açık sunucu kararıyla durdurur', () {
    Future<SurumDurumu> denetle(
      Future<int?> Function() kod,
      Future<Object?> Function() ayar,
    ) async => (await SurumDenetimi(
      uygulama: _Surum(kod),
      ayar: _Ayar(ayar),
      sure: const Duration(milliseconds: 50),
    ).denetle()).durum;

    test('Sunucu kararı uygulanır', () async {
      expect(
        await denetle(() async => 18, () async => belge()),
        SurumDurumu.guncellemeGerekli,
      );
    });

    test('Web (sürüm yok): sunucu hiç sorulmaz', () async {
      final ayar = _Ayar(() async => belge());
      final s = await SurumDenetimi(
        uygulama: const KapaliUygulamaSurumu(),
        ayar: ayar,
      ).denetle();
      expect((s.durum, ayar.okuma), (SurumDurumu.guncel, 0));
    });

    test(
      'Çevrimdışı, gecikme, belge yok/bozuk, kanal hatası: açılır',
      () async {
        for (final (kod, ayar)
            in <(Future<int?> Function(), Future<Object?> Function())>[
              (() async => 18, () async => throw StateError('unavailable')),
              (() async => 18, () => Completer<Object?>().future),
              (() async => 18, () async => null),
              (() async => 18, () async => belge({'enDusuk': 'x'})),
              (() async => throw StateError('kanal'), () async => belge()),
            ]) {
          expect(await denetle(kod, ayar), SurumDurumu.guncel);
        }
      },
    );
  });

  testWidgets('Güncelleme gerekli: yalnız indirme ve çıkış', (tester) async {
    var cikis = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GuncellemeSayfasi(
          bilgi: AndroidSurumu.coz(belge())!,
          cikis: () async => cikis++,
        ),
      ),
    );
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    final link = tester.widget<Link>(find.byType(Link));
    expect(link.uri, Uri.parse('https://indir.example.test/'));
    expect(link.target, LinkTarget.blank);
    expect(find.text('0.11.2 sürümünü indir'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    expect(cikis, 1);
  });

  testWidgets('Yeni sürüm notu ana ekranda görünür ve kapatılır', (
    tester,
  ) async {
    await tester.pumpWidget(BupPosApp(guncelleme: AndroidSurumu.coz(belge())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denemeyi aç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır: 0.11.2'), findsOneWidget);
    expect(find.byType(GuncellemeNotu), findsOneWidget);
    await tester.tap(find.byTooltip('Notu kapat'));
    await tester.pumpAndSettle();
    expect(find.byType(GuncellemeNotu), findsNothing);
  });
}
