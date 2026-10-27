import 'package:bup_sanal_pos/application/denizpay_oturumu.dart';
import 'package:bup_sanal_pos/domain/denizpay.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/modeller.dart';
import 'package:bup_sanal_pos/domain/pos_girisi.dart';
import 'package:bup_sanal_pos/domain/tahsilat.dart';
import 'package:bup_sanal_pos/ui/denizpay_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'denizpay_oturumu_test.dart'
    show SahteBirakma, SahteTarayici, kartSayfasi, sonucSayfasi, vkn;

void main() {
  late SahteTarayici t;
  late SahteBirakma b;
  final kart = KartOzeti(
    id: 'k1',
    cariId: 'c1',
    ad: 'Örnek İş Kartı',
    sonDort: '1111',
    ay: 12,
    yil: 2030,
    cihazKayitId: 'r1',
  );
  final adres = DenizPayAdresi.canli;
  Uri sayfa(String yol) => adres.koken.replace(path: yol);

  Future<DenizPayOturumu> ac(WidgetTester tester, {KartOzeti? secili}) async {
    t = SahteTarayici();
    b = SahteBirakma();
    final o = DenizPayOturumu(
      baglam: DenizPayBaglami(
        giris: PosGirisBilgisi.kimlikten(vkn),
        kayit: PosGirisi(
          id: 'G' * 20,
          kullaniciId: 'u1',
          kullaniciAd: 'Örnek Satıcı',
          cariId: 'c1',
          cariAd: 'Örnek Market',
          kimlikNo: vkn,
          kartSonDort: secili?.sonDort ?? '',
        ),
        kart: secili,
      ),
      tarayici: t,
      adres: adres,
      birakma: b,
      kartiOku: () async => KartBilgileri(numara: '4111111111111111'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DenizPayEkrani(oturum: o, gorunum: const Placeholder()),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    // Sayfa yüklenirken ilerleme çubuğu döner: "durana kadar" beklenmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return o;
  }

  testWidgets('Açılışta oturum temizlenip girilir; üstte cari ve adres', (
    tester,
  ) async {
    final o = await ac(tester);
    expect(t.olaylar.take(2), [
      'temizle',
      'giris https://denizpay.bupilic.com.tr/login.aspx $vkn 0001',
    ]);
    expect(find.text('Örnek Market'), findsOneWidget);
    expect(find.text('VKN / TC $vkn'), findsOneWidget);
    await o.sayfaYuklendi(Uri.parse('https://acs.banka.example/3d'));
    await tester.pump();
    expect(find.text('Banka sayfası: acs.banka.example'), findsOneWidget);
  });

  testWidgets('Kart sayfasında "Kartı doldur" kartı yazar ve sonucu söyler', (
    tester,
  ) async {
    final o = await ac(tester, secili: kart);
    t.ozet = kartSayfasi();
    await o.sayfaYuklendi(sayfa('/odeme.aspx'));
    await tester.pump();
    await tester.tap(find.text('Kartı doldur (•••• 1111)'));
    await tester.pumpAndSettle();
    expect(t.yazilan?['numara'], '4111111111111111');
    expect(find.textContaining('Kart yazıldı (•••• 1111)'), findsOneWidget);
  });

  testWidgets('Kart seçilmeden girildiyse kartı kendin yaz notu, düğme yok', (
    tester,
  ) async {
    final o = await ac(tester);
    t.ozet = kartSayfasi();
    await o.sayfaYuklendi(sayfa('/odeme.aspx'));
    await tester.pump();
    expect(find.textContaining('Kart seçmedin'), findsOneWidget);
    expect(find.textContaining('Kartı doldur'), findsNothing);
  });

  testWidgets(
    'Sonuç onayla kaydedilir; yanıt gösterilir; kapanınca oturum silinir',
    (tester) async {
      final o = await ac(tester);
      t.ozet = sonucSayfasi();
      await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
      await tester.pump();
      expect(
        find.textContaining('Ödeme başarılı · 4.500,00 TL'),
        findsOneWidget,
      );
      // Kaydetmeden kapatma onay ister; vazgeçince ekran kalır.
      await tester.tap(find.byTooltip('DenizPay’i kapat'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sonucu henüz bu cariye kaydetmedin'),
        findsOneWidget,
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu cariye kaydet: Örnek Market'));
      await tester.pumpAndSettle();
      expect(b.birakilan.single['posSiparisNo'], 'VP10000000000000001');
      b.yanitla('VP10000000000000001', true, 'Kaydedildi: Örnek Market');
      await tester.pumpAndSettle();
      expect(find.text('Kaydedildi: Örnek Market'), findsOneWidget);
      expect(find.textContaining('Bu cariye kaydet'), findsNothing);
      t.olaylar.clear();
      await tester.tap(find.byTooltip('DenizPay’i kapat'));
      await tester.pumpAndSettle();
      expect(find.text('aç'), findsOneWidget);
      expect(t.olaylar, ['temizle']);
    },
  );

  testWidgets('Başarısız sonuç açıklamasıyla gösterilir', (tester) async {
    final o = await ac(tester);
    t.ozet = {
      ...sonucSayfasi(form: 'Hata Formu'),
      'alanlar': [
        ['Açıklama', '3D Şifresi Yanlış.'],
        ['Pos Sipariş Numarası', 'VP2000'],
        ['Tutar', '100'],
      ],
    };
    await o.sayfaYuklendi(sayfa('/sonuc.aspx'));
    await tester.pump();
    expect(o.durum.sonuc!.sonuc, IslemSonucu.hata);
    expect(find.textContaining('Ödeme başarısız'), findsOneWidget);
    expect(find.textContaining('3D Şifresi Yanlış.'), findsOneWidget);
  });
}
