import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/application/hesap_portu.dart';
import 'package:bup_sanal_pos/application/pos_servisi.dart';
import 'package:bup_sanal_pos/data/demo_deposu.dart';
import 'package:bup_sanal_pos/domain/hata.dart';
import 'package:bup_sanal_pos/domain/kullanici.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/ui/giris_sayfasi.dart';
import 'package:bup_sanal_pos/ui/oturum_modeli.dart';
import 'package:bup_sanal_pos/ui/parola_sayfasi.dart';
import 'package:bup_sanal_pos/ui/tema.dart';

class SahteHesap implements HesapPortu {
  Future<void> Function()? bekle;
  int girisSayisi = 0, sifirlaSayisi = 0;
  int parolaDegistirmeSayisi = 0;
  @override
  String? get kimlik => null;
  @override
  Stream<String?> get degisimler => const Stream.empty();
  @override
  Future<void> giris(String eposta, String parola) async {
    girisSayisi++;
    await bekle?.call();
  }

  @override
  Future<void> cikis() async {}
  @override
  Future<void> parolaSifirla(String eposta) async {
    sifirlaSayisi++;
  }

  @override
  Future<void> yenidenDogrula(String parola) async {}
  @override
  Future<void> parolaDegistir(String mevcut, String yeni) async {
    parolaDegistirmeSayisi++;
  }

  @override
  Future<Kullanici> profil() async => throw UnimplementedError();
  @override
  Stream<Kullanici?> profilIzle() => const Stream.empty();
}

Future<void> ac(WidgetTester t, SahteHesap h) async {
  await t.pumpWidget(
    MaterialApp(
      theme: posTemasi(),
      home: GirisSayfasi(hesap: h),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> gir(WidgetTester t) async {
  await t.enterText(
    find.widgetWithText(TextFormField, 'E-posta'),
    'ornek@example.test',
  );
  await t.enterText(
    find.widgetWithText(TextFormField, 'Şifre'),
    'YapayUzunSifre-01',
  );
  await t.ensureVisible(find.text('Giriş yap'));
  await t.tap(find.text('Giriş yap'));
  await t.pump();
}

void main() {
  profilHatasiTestleri();
  testWidgets('Şifre değişiminde beş karakter reddedilir, altı kabul edilir', (
    t,
  ) async {
    final h = SahteHesap();
    await t.pumpWidget(
      MaterialApp(
        theme: posTemasi(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ParolaSayfasi(hesap: h),
                ),
              ),
              child: const Text('Şifre ekranını aç'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Şifre ekranını aç'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Mevcut şifre'),
      'OrnekEski!',
    );
    for (final yeni in ['Orn5!', 'Orn6ab']) {
      await t.enterText(find.widgetWithText(TextField, 'Yeni şifre'), yeni);
      await t.enterText(
        find.widgetWithText(TextField, 'Yeni şifre tekrar'),
        yeni,
      );
      await t.ensureVisible(find.text('Şifreyi güncelle'));
      await t.tap(find.text('Şifreyi güncelle'));
      await t.pumpAndSettle();
      expect(h.parolaDegistirmeSayisi, yeni.length < 6 ? 0 : 1);
    }
    expect(find.text('Şifren güncellendi.'), findsOneWidget);
  });
  testWidgets('Boş giriş sunucuya istek göndermeden reddedilir', (t) async {
    final h = SahteHesap();
    await ac(t, h);
    await t.tap(find.text('Giriş yap'));
    await t.pumpAndSettle();
    expect(h.girisSayisi, 0);
    expect(find.text('Şifreni yaz.'), findsOneWidget);
  });
  testWidgets('Bekleyen giriş ikinci kez gönderilemez', (t) async {
    final c = Completer<void>(), h = SahteHesap();
    h.bekle = () => c.future;
    await ac(t, h);
    await gir(t);
    final buton = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kontrol ediliyor…'),
    );
    expect(buton.onPressed, isNull);
    expect(h.girisSayisi, 1);
    c.complete();
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Şifre'))
          .controller!
          .text,
      isEmpty,
    );
  });
  testWidgets('Giriş tamamlanmadan ekran kapanırsa geç yanıt hata oluşturmaz', (
    t,
  ) async {
    final c = Completer<void>(), h = SahteHesap();
    h.bekle = () => c.future;
    await ac(t, h);
    await gir(t);
    await t.pumpWidget(const SizedBox());
    c.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('Yanlış girişte şifre bırakılır ve güvenli hata gösterilir', (
    t,
  ) async {
    final h = SahteHesap();
    h.bekle = () async => throw const PosHatasi('giris', 'Giriş yapılamadı.');
    await ac(t, h);
    await gir(t);
    await t.pumpAndSettle();
    expect(find.text('Giriş yapılamadı.'), findsOneWidget);
    expect(
      t
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Şifre'))
          .controller!
          .text,
      isEmpty,
    );
  });
  test('Kart özeti düzenleme ve silme seçili eski kartı bırakır', () async {
    final model = OturumModeli(
      PosServisi(
        depo: DemoDeposu(),
        baglanti: DemoPosBaglantisi(),
        kullaniciId: DemoDeposu.kullanici,
      ),
      deneme: false,
    );
    await model.yukle();
    await model.profilAc('demo-cari-0');
    final eski = model.profil!.kartlar.first;
    model.kartSec(eski);
    final yeni = KartOzeti(
      id: eski.id,
      cariId: eski.cariId,
      ad: 'Örnek Düzenlenen Kart',
      sonDort: '0088',
      ay: 12,
      yil: 2030,
    );
    expect(await model.kartKaydet(yeni), isTrue);
    expect(model.seciliKart, isNull);
    expect(
      model.profil!.kartlar.firstWhere((k) => k.id == eski.id).sonDort,
      '0088',
    );
    expect(await model.kartSil(eski.id), isTrue);
    expect(model.profil!.kartlar.any((k) => k.id == eski.id), isFalse);
    model.dispose();
  });
  test('Vergi numarası biçimi ve kayıt düzenlenirken korunması', () {
    final c = Cari(
      id: 'ornek',
      sahipId: 'ornek-kullanici',
      ad: 'Örnek Cari',
      kod: 'OR-001',
      kimlikNo: '0000000000',
    );
    expect(c.duzenle(ad: 'Örnek Yeni Ad').kimlikNo, c.kimlikNo);
    expect(() => c.duzenle(kimlikNo: 'gecersiz'), throwsA(isA<PosHatasi>()));
  });
}

void profilHatasiTestleri() {
  test('Doğrulanmış kullanıcı geçici bağlantı hatasında ekrandan atılmaz', () {
    const baglanti = PosHatasi('baglanti', 'Erişim sunucuda doğrulanıyor.');
    expect(
      profilHatasiOturumuKapatir(baglanti, dogrulanmisKullaniciVar: true),
      isFalse,
    );
    // İlk doğrulama yoksa önbellek kaydı güvenilmez: oturum açılmaz.
    expect(
      profilHatasiOturumuKapatir(baglanti, dogrulanmisKullaniciVar: false),
      isTrue,
    );
    // Başka her hata oturumu kapatır.
    for (final h in [
      const PosHatasi('yetki', 'Erişim yok.'),
      StateError('x'),
    ]) {
      expect(
        profilHatasiOturumuKapatir(h, dogrulanmisKullaniciVar: true),
        isTrue,
      );
    }
  });
}
