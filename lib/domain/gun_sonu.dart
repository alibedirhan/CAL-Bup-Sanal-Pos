import 'modeller.dart';
import 'tahsilat.dart';

/// Bir carinin bir gündeki işlemleri. Toplam yalnız başarılı ve tutarı
/// okunabilen işlemlerden oluşur; okunamayanlar ayrıca sayılır.
class CariGunOzeti {
  CariGunOzeti._(
    this.cariId,
    this.cariAd,
    this.kimlikNo,
    this.islemler,
    this.girisSayisi,
    this.sonucBekliyor,
  );
  final String cariId, cariAd, kimlikNo;

  /// Saate göre sıralı.
  final List<PosIslemi> islemler;
  final int girisSayisi;

  /// Son DenizPay girişinden sonra sonuç kaydedilmedi (yer imine dokunulmadı).
  final bool sonucBekliyor;

  Iterable<PosIslemi> get basarililar => islemler.where((i) => i.basarili);
  int get basariliAdet => basarililar.length;
  int get hataAdet => islemler.length - basariliAdet;
  int get toplamKurus => basarililar.fold(0, (t, i) => t + (i.tutarKurus ?? 0));
  int get okunamayanAdet =>
      basarililar.where((i) => i.tutarKurus == null).length;
}

/// Bir günün kayıtlarından hesaplanan gün sonu. Kayıtlar değiştirilemediği
/// için kapanmış bir günün gün sonu her açılışta aynıdır.
class GunSonu {
  GunSonu._(this.gun, this.cariler);
  final Gun gun;

  /// Cari adına göre (Türkçe) sıralı.
  final List<CariGunOzeti> cariler;

  /// Giriş ve işlem kayıtlarından gün sonunu çıkarır; başka güne ait kayıt alınmaz.
  factory GunSonu.hesapla(
    Gun gun,
    Iterable<PosGirisi> girisler,
    Iterable<PosIslemi> islemler,
  ) {
    bool bugun(DateTime? z) =>
        z != null && !z.isBefore(gun.baslangic) && z.isBefore(gun.bitis);
    final g = girisler.where((x) => bugun(x.zaman)).toList();
    final i = islemler.where((x) => bugun(x.zaman)).toList()
      ..sort((a, b) => a.zaman!.compareTo(b.zaman!));
    final kimlikler = {...g.map((x) => x.cariId), ...i.map((x) => x.cariId)};
    final cariler =
        [
          for (final id in kimlikler)
            _cari(
              id,
              [...g.where((x) => x.cariId == id)],
              [...i.where((x) => x.cariId == id)],
            ),
        ]..sort(
          (a, b) => aramaAnahtari(a.cariAd).compareTo(aramaAnahtari(b.cariAd)),
        );
    return GunSonu._(gun, List.unmodifiable(cariler));
  }

  static CariGunOzeti _cari(
    String id,
    List<PosGirisi> girisler,
    List<PosIslemi> islemler,
  ) {
    // Ad ve VKN en son kayıttan alınır (cari gün içinde yeniden adlandırılmış olabilir).
    DateTime? sonGiris, sonIslem;
    String ad = '', kimlik = '';
    for (final x in girisler) {
      if (sonGiris == null || x.zaman!.isAfter(sonGiris)) {
        sonGiris = x.zaman;
        ad = x.cariAd;
        kimlik = x.kimlikNo;
      }
    }
    if (islemler.isNotEmpty) {
      sonIslem = islemler.last.zaman;
      if (sonGiris == null || !sonIslem!.isBefore(sonGiris)) {
        ad = islemler.last.cariAd;
        kimlik = islemler.last.kimlikNo;
      }
    }
    return CariGunOzeti._(
      id,
      ad,
      kimlik,
      List.unmodifiable(islemler),
      girisler.length,
      sonGiris != null && (sonIslem == null || sonIslem.isBefore(sonGiris)),
    );
  }

  Iterable<PosIslemi> get islemler => cariler.expand((c) => c.islemler);
  int get toplamKurus => cariler.fold(0, (t, c) => t + c.toplamKurus);
  int get basariliAdet => cariler.fold(0, (t, c) => t + c.basariliAdet);
  int get hataAdet => cariler.fold(0, (t, c) => t + c.hataAdet);
  int get okunamayanAdet => cariler.fold(0, (t, c) => t + c.okunamayanAdet);
  Iterable<CariGunOzeti> get sonucBekleyenler =>
      cariler.where((c) => c.sonucBekliyor);
  bool get bos => cariler.isEmpty;
}

/// Excel'in Türkçe ayarıyla açılan CSV: noktalı virgül ayraç, virgüllü kuruş,
/// UTF-8 BOM. Formül gibi başlayan hücreler metin olarak kalır.
String gunSonuCsv(GunSonu g) {
  String hucre(String v) {
    final d = RegExp(r'^[=+\-@\t\r]').hasMatch(v) ? "'$v" : v;
    return '"${d.replaceAll('"', '""')}"';
  }

  final satirlar = <List<String>>[
    [
      'Tarih',
      'Saat',
      'Cari',
      'VKN / TC',
      'Sonuç',
      'Tutar (TL)',
      'Tutar (DenizPay yazısı)',
      'Pos Sipariş No',
      'Üye Sipariş No',
      'Kart',
      'Açıklama',
      'Kullanıcı',
      'Kayıt',
    ],
    for (final i in g.islemler)
      [
        g.gun.etiket,
        saatYaz(i.zaman!),
        i.cariAd,
        i.kimlikNo,
        i.basarili ? 'Başarılı' : 'Başarısız',
        i.tutarKurus == null
            ? ''
            : '${i.tutarKurus! ~/ 100},${(i.tutarKurus! % 100).toString().padLeft(2, '0')}',
        i.tutarMetni,
        i.posSiparisNo,
        i.uyeSiparisNo,
        i.kartSonDort.isEmpty ? '' : '•••• ${i.kartSonDort}',
        i.aciklama,
        i.kullaniciAd,
        i.kaynak == IslemKaynagi.elle ? 'Elle' : 'Sonuç ekranından',
      ],
  ];
  return '﻿${satirlar.map((s) => s.map(hucre).join(';')).join('\r\n')}\r\n';
}
