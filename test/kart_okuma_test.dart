import 'package:flutter_test/flutter_test.dart';
import 'package:bup_sanal_pos/domain/kart_bilgileri.dart';
import 'package:bup_sanal_pos/domain/kart_okuma.dart';

// Yalnız herkese açık deneme kart numaraları ve uydurma adlar kullanılır.
final simdi = DateTime(2026, 10, 21);
OkunanKart oku(String metin) => kartMetniniOku(metin, simdi: simdi);

void main() {
  test('Yıl ve tek kutu tarih biçimleri doğru çözülür', () {
    expect(sktYili('31'), 2031);
    expect(sktYili('2031'), 2031);
    expect(sktYili(' 31 '), 2031);
    for (final bozuk in ['1', '312', '3000', '19x9', '']) {
      expect(sktYili(bozuk), isNull, reason: bozuk);
    }
    expect(sktCoz('07/31'), (ay: 7, yil: 2031));
    expect(sktCoz('7 / 2031'), (ay: 7, yil: 2031));
    expect(sktCoz('07-31'), (ay: 7, yil: 2031));
    expect(sktCoz('13/31'), isNull);
    expect(sktCoz('0731'), isNull);
  });

  test('Kart numarası tire ve boşlukla da kabul edilir', () {
    expect(kartNumarasi('4111-1111-1111-1111'), '4111111111111111');
    expect(kartNumarasi('4111 1111 1111 1111'), '4111111111111111');
  });

  test('Telefonun kopyaladığı kart yazısından üç alan doğru çıkar', () {
    final k = oku(
      'ÖRNEK BANKASI\nBONUS\n4111 1111 1111 1111\nVALID\nTHRU 07/31\n'
      'AHMET YILMAZ\nVISA',
    );
    expect(k.numara, '4111111111111111');
    expect((k.ay, k.yil), (7, 2031));
    expect(k.ad, 'AHMET YILMAZ');
  });

  test('OCR harf karışıklıkları rakam gruplarında düzeltilir', () {
    expect(oku('4lll 1111 IIII 1111').numara, '4111111111111111');
    expect(oku('5555 5555 5555 4444').numara, '5555555555554444');
    expect(oku('3782 822463 10005').numara, '378282246310005');
  });

  test('İki satıra bölünmüş numara birleştirilir', () {
    expect(oku('4111 1111\n1111 1111').numara, '4111111111111111');
  });

  test('Kontrolden geçmeyen veya birden çok numarada numara boş kalır', () {
    expect(oku('4111 1111 1111 1112').numara, isNull);
    expect(oku('4111 1111 1111 1111\n5555 5555 5555 4444').numara, isNull);
    expect(oku('Telefon 0532 000 00 00').numara, isNull);
  });

  test('Son kullanma: etiketli tarih, başlangıç tarihi atlanır', () {
    final a = oku('VALID FROM 01/24 THRU 07/31');
    expect((a.ay, a.yil), (7, 2031));
    final b = oku('SKT\n11/2029');
    expect((b.ay, b.yil), (11, 2029));
    final c = oku('01/24   07/31');
    expect((c.ay, c.yil), (7, 2031), reason: 'etiketsiz iki tarihte geç olan');
  });

  test('Eski, uzak veya çok sayıda belirsiz tarihte tarih boş kalır', () {
    expect(oku('THRU 07/19').ay, isNull);
    expect(oku('THRU 07/70').ay, isNull);
    expect(oku('01/27 05/28 09/29').ay, isNull);
  });

  test('Ad: Türkçe harfli büyük yazı kabul, banka/ürün/etiket reddedilir', () {
    expect(oku('ŞÜKRÜ ÖZTÜRK').ad, 'ŞÜKRÜ ÖZTÜRK');
    expect(oku('AYŞE NUR GÜLER').ad, 'AYŞE NUR GÜLER');
    for (final ad in [
      'WORLD ELITE',
      'GARANTİ BBVA',
      'VALID THRU',
      'Ahmet Yılmaz',
      'AHMET',
      'KART SAHİBİ',
    ]) {
      expect(oku(ad).ad, isNull, reason: ad);
    }
    expect(oku('AHMET YILMAZ\nMEHMET KAYA').ad, isNull, reason: 'iki aday');
  });

  test('CVV ve diğer sayılar hiçbir alana girmez', () {
    final k = oku('4111 1111 1111 1111\nCVV 123\nTHRU 07/31');
    expect(k.numara, '4111111111111111');
    expect((k.ay, k.yil), (7, 2031));
    expect(k.ad, isNull);
    expect(oku('CVV 123').bos, isTrue);
  });

  test('Çok uzun metin işlenmez', () {
    expect(oku('4111 1111 1111 1111 ${'A' * 5000}').bos, isTrue);
  });
}
