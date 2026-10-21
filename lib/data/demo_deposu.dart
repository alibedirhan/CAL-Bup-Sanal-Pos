import '../application/portlar.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';

/// Yalnız oturum belleğinde, tamamı yapay kayıtlar. Canlı depo değildir.
class DemoDeposu implements CariDeposu {
  DemoDeposu({DateTime? simdi}) {
    final yil = (simdi ?? DateTime.now()).year;
    const adlar = [
      'Örnek Kuzey Market',
      'Örnek Sahil Gıda',
      'Örnek Çınar Büfe',
      'Örnek Ada Market',
      'Örnek Bahçe Restoran',
      'Örnek Park Gıda',
    ];
    for (var i = 0; i < adlar.length; i++) {
      final id = 'demo-cari-$i';
      _cariler[id] = Cari(
        id: id,
        sahipId: kullanici,
        ad: adlar[i],
        kod: 'OR-${(i + 1).toString().padLeft(3, '0')}',
        kimlikNo: (i + 1).toString().padLeft(10, '0'),
        yildizli: i < 2,
      );
      _kartlar[id] = i == 5
          ? []
          : [
              KartOzeti(
                id: 'demo-kart-$i',
                cariId: id,
                ad: 'İş kartı',
                sonDort: '00${(i + 1).toString().padLeft(2, '0')}',
                ay: 12,
                yil: yil + 2,
              ),
            ];
    }
    _kartlar['demo-cari-0']!.add(
      KartOzeti(
        id: 'demo-ek-kart',
        cariId: 'demo-cari-0',
        ad: 'Diğer kart',
        sonDort: '0080',
        ay: 6,
        yil: yil + 1,
      ),
    );
    _kartlar['demo-cari-1']!.add(
      KartOzeti(
        id: 'demo-gecmis-kart',
        cariId: 'demo-cari-1',
        ad: 'Eski kart',
        sonDort: '0090',
        ay: 1,
        yil: yil - 1,
      ),
    );
    _cariler['baska-cari'] = Cari(
      id: 'baska-cari',
      sahipId: 'baska-kullanici',
      ad: 'Başka Kullanıcının Örnek Carisi',
      kod: 'DIGER-01',
    );
    _kartlar['baska-cari'] = [];
  }
  static const kullanici = 'demo-kullanici';
  @override
  Future<void> kartKaydet(
    String uid,
    String id,
    int surum,
    KartOzeti kart,
  ) async {
    final cari = _yetkili(uid, id);
    _surum(cari, surum);
    if (kart.cariId != id) {
      throw const PosHatasi('kart', 'Kart cariye ait değil.');
    }
    final liste = _kartlar[id]!;
    final index = liste.indexWhere((k) => k.id == kart.id);
    if (index < 0 && liste.length >= 10) {
      throw const PosHatasi('sinir', 'En fazla 10 kart özeti eklenebilir.');
    }
    if (index < 0) {
      liste.add(kart);
    } else {
      liste[index] = kart;
    }
    _cariler[id] = cari.duzenle();
  }

  @override
  Future<void> kartSil(String uid, String id, int surum, String kartId) async {
    final cari = _yetkili(uid, id);
    _surum(cari, surum);
    _kartlar[id]!.removeWhere((k) => k.id == kartId);
    _cariler[id] = cari.duzenle();
  }

  final _cariler = <String, Cari>{};
  final _kartlar = <String, List<KartOzeti>>{};
  int _sira = 100;

  Cari _yetkili(String kullaniciId, String id) {
    final cari = _cariler[id];
    if (cari == null || cari.sahipId != kullaniciId) {
      throw const PosHatasi(
        'erisilemiyor',
        'Cari bulunamadı veya bu kayda erişiminiz yok.',
      );
    }
    return cari;
  }

  void _surum(Cari cari, int beklenen) {
    if (cari.surum != beklenen) {
      throw const PosHatasi(
        'surum',
        'Kayıt değişti. Güncel bilgiyi açıp yeniden deneyin.',
      );
    }
  }

  void _kodKontrol(String kullaniciId, String kod, {String? haric}) {
    if (_cariler.values.any(
      (c) =>
          c.sahipId == kullaniciId &&
          c.id != haric &&
          c.kod.toUpperCase() == kod.trim().toUpperCase(),
    )) {
      throw const PosHatasi(
        'ayni_kod',
        'Bu cari kodu zaten kullanılıyor. Farklı bir kod yazın.',
      );
    }
  }

  @override
  Future<List<CariOzeti>> listele(String kullaniciId) async =>
      List.unmodifiable(
        _cariler.values
            .where((c) => c.sahipId == kullaniciId)
            .map((c) => CariOzeti(c, _kartlar[c.id]?.length ?? 0)),
      );
  @override
  Future<CariProfili> profil(String kullaniciId, String cariId) async =>
      CariProfili(_yetkili(kullaniciId, cariId), _kartlar[cariId] ?? []);
  @override
  Future<Cari> ekle(
    String kullaniciId,
    String ad,
    String kod, {
    String kimlikNo = '',
  }) async {
    if (kullaniciId != kullanici) {
      throw const PosHatasi('erisim', 'Deneme oturumu geçerli değil.');
    }
    final cari = Cari(
      id: 'yeni-cari-${_sira++}',
      sahipId: kullaniciId,
      ad: ad,
      kod: kod,
      kimlikNo: kimlikNo,
    );
    _kodKontrol(kullaniciId, cari.kod);
    _cariler[cari.id] = cari;
    _kartlar[cari.id] = [];
    return cari;
  }

  @override
  Future<void> kaydet(String kullaniciId, Cari cari, int beklenenSurum) async {
    final eski = _yetkili(kullaniciId, cari.id);
    _surum(eski, beklenenSurum);
    if (cari.sahipId != eski.sahipId || cari.surum != eski.surum + 1) {
      throw const PosHatasi('surum', 'Cari kaydı doğrulanamadı.');
    }
    _kodKontrol(kullaniciId, cari.kod, haric: cari.id);
    _cariler[cari.id] = cari;
  }

  @override
  Future<void> sil(String kullaniciId, String cariId, int beklenenSurum) async {
    _surum(_yetkili(kullaniciId, cariId), beklenenSurum);
    _cariler.remove(cariId);
    _kartlar.remove(cariId);
  }

  @override
  Future<void> denemeKartiEkle(String kullaniciId, String cariId) async {
    final cari = _yetkili(kullaniciId, cariId);
    final kartlar = _kartlar[cariId]!;
    if (kartlar.length >= 10) {
      throw const PosHatasi(
        'sinir',
        'Bir cariye en fazla 10 deneme kartı eklenebilir.',
      );
    }
    final sira = _sira++;
    kartlar.add(
      KartOzeti(
        id: 'eklenen-$sira',
        cariId: cariId,
        ad: 'Deneme kartı ${kartlar.length + 1}',
        sonDort: sira.toString().padLeft(4, '0'),
        ay: 12,
        yil: DateTime.now().year + 2,
      ),
    );
    _cariler[cariId] = cari.duzenle();
  }
}

class DemoPosBaglantisi implements PosBaglantisi {
  @override
  Future<DenemeSonucu> dene(Cari cari, KartOzeti kart) async =>
      DenemeSonucu(cari.ad, kart.sonDort);
}

/// Sağlayıcı doğrulanmadan üretim yolu açılmaz.
class KapaliPosBaglantisi implements PosBaglantisi {
  @override
  Future<DenemeSonucu> dene(Cari cari, KartOzeti kart) async =>
      throw const PosHatasi(
        'saglayici_yok',
        'Gerçek POS bağlantısı henüz kurulmadı.',
      );
}
