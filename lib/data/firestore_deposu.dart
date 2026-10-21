import 'package:cloud_firestore/cloud_firestore.dart';
import '../application/portlar.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import 'firestore_esleme.dart';

class FirestoreDeposu implements CariDeposu, CariIzlemePortu {
  FirestoreDeposu(this.db);
  final FirebaseFirestore db;
  @override
  Stream<List<CariOzeti>> izle(String kullaniciId) => _cariler
      .where('sahipId', isEqualTo: kullaniciId)
      .where('silindi', isEqualTo: false)
      .limit(1000)
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        if (s.metadata.isFromCache) {
          throw const PosHatasi(
            'baglanti',
            'Sunucu bağlantısı doğrulanıyor. İnternet bağlantını kontrol et.',
          );
        }
        if (s.docs.length >= 1000) {
          throw const PosHatasi('sinir', 'Cari liste sınırına ulaşıldı.');
        }
        return s.docs.map((d) {
          final p = cariOku(d.id, d.data());
          return CariOzeti(p.cari, p.kartlar.length);
        }).toList();
      });
  CollectionReference<Map<String, dynamic>> get _cariler =>
      db.collection('cariler');
  DocumentReference<Map<String, dynamic>> _kod(String uid, String kod) =>
      db.collection('cariKodlari').doc('${uid}_${kod.toUpperCase()}');
  Future<T> _dene<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Future<List<CariOzeti>> listele(String kullaniciId) => _dene(() async {
    final sonuc = await _cariler
        .where('sahipId', isEqualTo: kullaniciId)
        .where('silindi', isEqualTo: false)
        .limit(1000)
        .get(const GetOptions(source: Source.server));
    if (sonuc.docs.length >= 1000) {
      throw const PosHatasi(
        'sinir',
        'Cari sayısı liste sınırına ulaştı. Yöneticiyle görüşün.',
      );
    }
    return sonuc.docs.map((d) {
      final p = cariOku(d.id, d.data());
      return CariOzeti(p.cari, p.kartlar.length);
    }).toList();
  });
  @override
  Future<CariProfili> profil(String kullaniciId, String cariId) =>
      _dene(() async {
        final doc = await _cariler
            .doc(cariId)
            .get(const GetOptions(source: Source.server));
        return cariOku(doc.id, doc.data());
      });
  void _iz(Transaction tx, Cari c, String uid, String eylem) {
    tx.set(db.collection('denetim').doc('${c.id}_${c.surum}'), {
      'kullaniciId': uid,
      'cariId': c.id,
      'surum': c.surum,
      'eylem': eylem,
      'zaman': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Cari> ekle(
    String kullaniciId,
    String ad,
    String kod, {
    String kimlikNo = '',
  }) => _dene(() async {
    final ref = _cariler.doc();
    final c = Cari(
      id: ref.id,
      sahipId: kullaniciId,
      ad: ad,
      kod: kod,
      kimlikNo: kimlikNo,
    );
    await db.runTransaction((tx) async {
      final code = _kod(kullaniciId, c.kod);
      if ((await tx.get(code)).exists) {
        throw const PosHatasi(
          'ayni_kod',
          'Bu vergi / TC numarası zaten kayıtlı. Mevcut cariyi aç.',
        );
      }
      tx.set(ref, cariYaz(c, []));
      tx.set(code, {
        'sahipId': kullaniciId,
        'kod': c.kod.toUpperCase(),
        'cariId': c.id,
      });
      _iz(tx, c, kullaniciId, 'ekle');
    });
    return c;
  });

  Future<void> _degistir(
    String uid,
    String id,
    int surum,
    CariProfili Function(CariProfili) donustur, {
    bool sil = false,
  }) => _dene(() async {
    await db.runTransaction((tx) async {
      final ref = _cariler.doc(id);
      final doc = await tx.get(ref);
      final eski = cariOku(id, doc.data());
      if (eski.cari.surum != surum) {
        throw const PosHatasi(
          'surum',
          'Kayıt değişti. Güncel bilgiyi açıp yeniden deneyin.',
        );
      }
      final yeni = donustur(eski);
      final degisenKartlar = yeni.kartlar
          .where((k) => !eski.kartlar.contains(k))
          .toList();
      final eskiKod = _kod(eski.cari.sahipId, eski.cari.kod);
      final yeniKod = _kod(yeni.cari.sahipId, yeni.cari.kod);
      final kodDegisti = eskiKod.path != yeniKod.path;
      if (kodDegisti && !sil && (await tx.get(yeniKod)).exists) {
        throw const PosHatasi(
          'ayni_kod',
          'Bu vergi / TC numarası zaten kayıtlı. Mevcut cariyi aç.',
        );
      }
      if (sil || kodDegisti) tx.delete(eskiKod);
      if (kodDegisti && !sil) {
        tx.set(yeniKod, {
          'sahipId': yeni.cari.sahipId,
          'kod': yeni.cari.kod.toUpperCase(),
          'cariId': id,
        });
      }
      tx.set(
        ref,
        cariYaz(
          yeni.cari,
          sil ? [] : yeni.kartlar,
          olusturma: doc.data()!['olusturma'],
          silindi: sil,
          sonKart: degisenKartlar.isEmpty || sil ? null : degisenKartlar.single,
        ),
      );
      _iz(tx, yeni.cari, uid, sil ? 'sil' : 'kaydet');
    });
  });
  @override
  Future<void> kaydet(String kullaniciId, Cari cari, int beklenenSurum) =>
      _degistir(
        kullaniciId,
        cari.id,
        beklenenSurum,
        (p) => CariProfili(cari, p.kartlar),
      );
  @override
  Future<void> sil(String kullaniciId, String cariId, int beklenenSurum) =>
      _degistir(
        kullaniciId,
        cariId,
        beklenenSurum,
        (p) => CariProfili(p.cari.duzenle(), []),
        sil: true,
      );
  @override
  Future<void> denemeKartiEkle(String kullaniciId, String cariId) async =>
      throw const PosHatasi(
        'deneme_yok',
        'Canlı kayıtlara deneme kartı eklenmez.',
      );
  @override
  Future<void> kartKaydet(
    String kullaniciId,
    String cariId,
    int beklenenSurum,
    KartOzeti kart,
  ) => _degistir(kullaniciId, cariId, beklenenSurum, (p) {
    if (kart.cariId != cariId) {
      throw const PosHatasi('kart', 'Kart cariye ait değil.');
    }
    final liste = p.kartlar.where((k) => k.id != kart.id).toList()..add(kart);
    if (liste.length > 10) {
      throw const PosHatasi('sinir', 'En fazla 10 kart özeti eklenebilir.');
    }
    return CariProfili(p.cari.duzenle(), liste);
  });
  @override
  Future<void> kartSil(
    String kullaniciId,
    String cariId,
    int beklenenSurum,
    String kartId,
  ) => _degistir(
    kullaniciId,
    cariId,
    beklenenSurum,
    (p) =>
        CariProfili(p.cari.duzenle(), p.kartlar.where((k) => k.id != kartId)),
  );

  Future<void> ata(String adminUid, String id, int surum, String yeniUid) =>
      _degistir(
        adminUid,
        id,
        surum,
        (p) => CariProfili(
          Cari(
            id: id,
            sahipId: yeniUid,
            ad: p.cari.ad,
            kod: p.cari.kod,
            yildizli: false,
            surum: p.cari.surum + 1,
            kimlikNo: p.cari.kimlikNo,
          ),
          p.kartlar,
        ),
      );
}
