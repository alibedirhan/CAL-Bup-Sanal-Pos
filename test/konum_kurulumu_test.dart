import 'package:bup_sanal_pos/application/hesap_portu.dart';
import 'package:bup_sanal_pos/application/rota_kurulumu.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/kullanici.dart';
import 'package:bup_sanal_pos/domain/rota_kurulumu.dart';
import 'package:bup_sanal_pos/ui/bilgi_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gizli konum kurulumu (docs/ROTA_MIMARI.md M16): yalnız yönetici, şifre
/// yeniden sorulmadan açılmaz; eksik adımlar düğmeyle gösterilir.
class _Hesap implements HesapPortu {
  final denenen = <String>[];
  @override
  Future<void> yenidenDogrula(String parola) async {
    denenen.add(parola);
    if (parola != 'dogru-sifre') {
      throw const PosHatasi('parola', 'Şifre yanlış.');
    }
  }

  @override
  Future<void> cikis() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Kurulum implements RotaKurulumPortu {
  _Kurulum(this.harita);
  Map<String, Object?> harita;
  final cagrilar = <String>[];
  @override
  Future<RotaKurulumDurumu> durum() async {
    cagrilar.add('durum');
    return RotaKurulumDurumu.haritadan(harita);
  }

  @override
  Future<bool> konumIzni() async {
    cagrilar.add('konumIzni');
    harita = {...harita, 'konumIzni': true};
    return true;
  }

  @override
  Future<bool> arkaPlanIzni() async {
    cagrilar.add('arkaPlanIzni');
    return false;
  }

  @override
  Future<void> pilMuafiyeti() async => cagrilar.add('pilMuafiyeti');
  @override
  Future<void> konumAyari() async => cagrilar.add('konumAyari');
  @override
  Future<bool> baslat() async {
    cagrilar.add('baslat');
    return true;
  }
}

final _yonetici = Kullanici(
  id: 'admin',
  ad: 'Örnek Yönetici',
  eposta: 'admin@example.test',
  yonetici: true,
  aktif: true,
);

Widget _sayfa(Kullanici k, HesapPortu h, RotaKurulumPortu? r) => MaterialApp(
  home: Scaffold(
    body: BilgiSayfasi(kilitle: () {}, kullanici: k, hesap: h, rotaKurulumu: r),
  ),
);

Future<void> _kurulumaGir(WidgetTester t) async {
  t.view.physicalSize = const Size(900, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpAndSettle();
  await t.ensureVisible(find.text('Yönetici kurulumu'));
  await t.pumpAndSettle();
  await t.tap(find.text('Yönetici kurulumu'));
}

void main() {
  test('Kanal haritası güvenli okunur', () {
    final d = RotaKurulumDurumu.haritadan({
      'etkin': true,
      'kod': 'K9WMEY',
      'konumIzni': true,
      'arkaPlanIzni': 'evet',
      'bekleyen': -5,
    });
    expect(d.kod, 'K9WMEY');
    expect(d.arkaPlanIzni, isFalse);
    expect(d.bekleyen, 0);
    expect(d.terminalHazir, isFalse);
    expect(RotaKurulumDurumu.haritadan({'kod': 'k9wmey'}).kod, isNull);
    expect(RotaKurulumDurumu.haritadan({'kod': 'IO01AB'}).kod, isNull);
  });

  testWidgets('Düğme yalnız yöneticiye ve kurulum varsa görünür', (t) async {
    final h = _Hesap();
    await t.pumpWidget(_sayfa(_yonetici, h, null));
    expect(find.text('Yönetici kurulumu'), findsNothing);
    final satici = Kullanici(
      id: 's',
      ad: 'Örnek Satıcı',
      eposta: 's@example.test',
      yonetici: false,
      aktif: true,
    );
    await t.pumpWidget(_sayfa(satici, h, _Kurulum({})));
    expect(find.text('Yönetici kurulumu'), findsNothing);
    await t.pumpWidget(_sayfa(_yonetici, h, _Kurulum({})));
    expect(find.text('Yönetici kurulumu'), findsOneWidget);
  });

  testWidgets('Şifre doğrulanmadan kurulum açılmaz', (t) async {
    final h = _Hesap();
    final r = _Kurulum({'etkin': true, 'kod': 'K9WMEY'});
    await t.pumpWidget(_sayfa(_yonetici, h, r));
    await _kurulumaGir(t);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'yanlis');
    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
    expect(find.text('Şifre yanlış.'), findsOneWidget);
    expect(find.text('Konum kurulumu'), findsNothing);
    expect(r.cagrilar, isEmpty);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(find.text('Konum kurulumu'), findsNothing);
    expect(h.denenen, ['yanlis']);
  });

  testWidgets('Kurulum adımları ve terminal kodu gösterilir', (t) async {
    final h = _Hesap();
    final r = _Kurulum({
      'etkin': true,
      'kod': 'K9WMEY',
      'pilMuaf': true,
      'konumAcik': true,
      'bekleyen': 12,
    });
    await t.pumpWidget(_sayfa(_yonetici, h, r));
    await _kurulumaGir(t);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'dogru-sifre');
    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
    expect(find.text('Konum kurulumu'), findsOneWidget);
    expect(find.text('K9WMEY'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('Bekliyor'), findsOneWidget);
    // Konum izni yokken arka plan ve başlat düğmeleri pasif.
    final arkaPlan = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'Her zaman izin ver'),
    );
    expect(arkaPlan.onPressed, isNull);
    expect(find.text('Kısıtlamayı kaldır'), findsNothing);
    await t.tap(find.text('İzin ver'));
    await t.pumpAndSettle();
    expect(r.cagrilar, contains('konumIzni'));
    expect(find.text('İzin ver'), findsNothing);
    expect(
      t
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Her zaman izin ver'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Deneme derlemesinde kurulum kapalı yazar', (t) async {
    final h = _Hesap();
    await t.pumpWidget(_sayfa(_yonetici, h, _Kurulum({'etkin': false})));
    await _kurulumaGir(t);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'dogru-sifre');
    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
    expect(find.text('Bu derlemede konum takibi kapalı.'), findsOneWidget);
  });
}
