import 'dart:convert';
import 'dart:io';
import 'package:bup_sanal_pos/data/android/sonuc_kutusu.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> kayit(
  String no, {
  String sonuc = 'basarili',
  int v = 3,
  String eslesme = 'uygulama_ici',
  DateTime? okunma,
}) => {
  'v': v,
  'eslesme': eslesme,
  'uid': 'u1',
  'girisId': 'G' * 20,
  'cariId': 'c1',
  'cariAd': 'Örnek Market',
  'kimlikNo': '0000000001',
  'kartSonDort': '',
  'sonuc': sonuc,
  'aciklama': 'Ödeme Başarıyla Gerçekleştirildi',
  'posSiparisNo': no,
  'uyeSiparisNo': '',
  'tutarMetni': '4500',
  'okunma': (okunma ?? simdi).millisecondsSinceEpoch,
};

final simdi = DateTime.utc(2026, 10, 27, 9);

void main() {
  late Directory klasor;
  setUp(() async => klasor = await Directory.systemTemp.createTemp('kutu-'));
  tearDown(() => klasor.delete(recursive: true));
  AndroidSonucKutusu yeni() =>
      AndroidSonucKutusu(klasor: () async => klasor.path, saat: () => simdi);
  File dosya() => File('${klasor.path}/sonuc-kutusu.json');

  test(
    'Bırakılan sonuç dosyada kalır, yeniden açılışta okunur ve bildirilir',
    () async {
      final k = yeni();
      var degisim = 0;
      k.degisimler.listen((_) => degisim++);
      expect(await k.birak(kayit('VP1000')), 'ok');
      expect(await k.birak(kayit('VP1000')), 'zaten');
      expect(await k.birak(kayit('VP1000', sonuc: 'hata')), 'ok'); // "-h" ayrı
      await Future<void>.delayed(Duration.zero);
      expect(degisim, 2);
      expect(k.oku(), hasLength(2));
      final ikinci = yeni();
      var acilis = 0;
      ikinci.degisimler.listen((_) => acilis++);
      await ikinci.hazir;
      await Future<void>.delayed(Duration.zero);
      expect(ikinci.oku().map((x) => x['posSiparisNo']), ['VP1000', 'VP1000']);
      expect(acilis, 1, reason: 'açılışta bekleyen sonuç varsa işlensin');
    },
  );

  test('Yalnız uygulama içi (v3) ve işlenebilir kayıt kabul edilir', () async {
    final k = yeni();
    for (final bozuk in [
      kayit('VP1000', v: 2, eslesme: 'tek_giris'),
      kayit('VP1000', eslesme: 'tek_giris'),
      kayit('VP1'),
      {...kayit('VP1000'), 'okunma': 'dun'},
      kayit('VP1000', okunma: simdi.subtract(const Duration(days: 31))),
      kayit('VP1000', okunma: simdi.add(const Duration(minutes: 5))),
    ]) {
      await expectLater(
        k.birak(bozuk),
        throwsFormatException,
        reason: '$bozuk',
      );
    }
    expect(await dosya().exists(), isFalse);
  });

  test('Silme kalıcıdır; okunan kayıt kopyadır; 20 sonuç sınırı', () async {
    final k = yeni();
    for (var i = 0; i < 22; i++) {
      await k.birak(kayit('VP${2000 + i}'));
    }
    expect(k.oku(), hasLength(20));
    expect(k.oku().first['posSiparisNo'], 'VP2002');
    k.oku().first['posSiparisNo'] = 'DEGISTI';
    expect(k.oku().first['posSiparisNo'], 'VP2002');
    k.sil('VP2002');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final d = jsonDecode(await dosya().readAsString()) as List;
    expect(d, hasLength(19));
    expect(d.any((x) => x['posSiparisNo'] == 'VP2002'), isFalse);
  });

  test(
    'Süresi dolan kayıt okunmaz; bozuk dosya silinmez, kenara alınır',
    () async {
      await dosya().writeAsString('{bozuk');
      final k = yeni();
      await k.hazir;
      expect(k.oku(), isEmpty);
      expect(await File('${dosya().path}.bozuk').readAsString(), '{bozuk');
      await dosya().writeAsString(
        jsonEncode([
          kayit('VP3000', okunma: simdi.subtract(const Duration(days: 30))),
          kayit('VP3001'),
        ]),
      );
      final k2 = yeni();
      await k2.hazir;
      expect(k2.oku().map((x) => x['posSiparisNo']), ['VP3001']);
    },
  );

  test('Yanıtlar DenizPay ekranına iletilir', () async {
    final k = yeni();
    final gelen = <String>[];
    k.yanitlar.listen((y) => gelen.add('${y.kimlik} ${y.tamam} ${y.mesaj}'));
    k.yanitla('VP1000', tamam: true, mesaj: 'Kaydedildi');
    await Future<void>.delayed(Duration.zero);
    expect(gelen, ['VP1000 true Kaydedildi']);
    expect(k.destekli, isTrue);
  });
}
