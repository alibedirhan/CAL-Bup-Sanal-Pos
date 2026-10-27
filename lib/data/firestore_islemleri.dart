import 'package:cloud_firestore/cloud_firestore.dart';
import '../application/tahsilat_servisi.dart';
import '../domain/hata.dart';
import '../domain/tahsilat.dart';
import 'firestore_esleme.dart';

/// `posGirisleri` ve `posIslemleri`: yalnız eklenir (firestore.rules). Zaman
/// sunucu saatidir; işlem belge kimliği [PosIslemi.kimlik]'tir (Pos Sipariş
/// Numarası, başarısız denemede "-h" ekli).
class FirestoreIslemDeposu implements IslemDeposu {
  FirestoreIslemDeposu(this.db);
  final FirebaseFirestore db;
  static const sinir = 1000;
  CollectionReference<Map<String, dynamic>> get _girisler =>
      db.collection('posGirisleri');
  CollectionReference<Map<String, dynamic>> get _islemler =>
      db.collection('posIslemleri');

  Future<T> _dene<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Future<void> girisKaydet(PosGirisi g) => _dene(
    () => _girisler.doc(g.id).set({
      'kullaniciId': g.kullaniciId,
      'kullaniciAd': g.kullaniciAd,
      'cariId': g.cariId,
      'cariAd': g.cariAd,
      'kimlikNo': g.kimlikNo,
      'kartSonDort': g.kartSonDort,
      'zaman': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<IslemKaydi> islemKaydet(PosIslemi i) => _dene(() async {
    final ref = _islemler.doc(i.kimlik);
    Future<DocumentSnapshot<Map<String, dynamic>>> oku() async {
      try {
        return await ref.get(const GetOptions(source: Source.server));
      } on FirebaseException catch (e) {
        // Kural, olmayan veya kendi kaydını okumaya izin verir; red başkasınındır.
        if (e.code == 'permission-denied') {
          throw const PosHatasi(
            'pos_no_baska',
            'Bu Pos Sipariş Numarası başka bir kullanıcı adına kayıtlı. Numarayı kontrol et.',
          );
        }
        rethrow;
      }
    }

    final mevcut = await oku();
    if (mevcut.exists) {
      return IslemKaydi(islemOku(mevcut.id, mevcut.data()!), zatenVardi: true);
    }
    try {
      await _yaz(ref, i);
    } on FirebaseException catch (_) {
      // Kayıt yalnız eklenir: aynı kayıt o arada başka sekmeden yazıldıysa
      // ikinci yazma reddedilir. Hata ancak kayıt gerçekten yoksa iletilir.
      final sonra = await oku();
      if (sonra.exists) {
        return IslemKaydi(islemOku(sonra.id, sonra.data()!), zatenVardi: true);
      }
      rethrow;
    }
    final yazilan = await ref.get(const GetOptions(source: Source.server));
    return IslemKaydi(islemOku(yazilan.id, yazilan.data()!), zatenVardi: false);
  });

  Future<void> _yaz(DocumentReference<Map<String, dynamic>> ref, PosIslemi i) =>
      ref.set({
        'kullaniciId': i.kullaniciId,
        'kullaniciAd': i.kullaniciAd,
        'cariId': i.cariId,
        'cariAd': i.cariAd,
        'kimlikNo': i.kimlikNo,
        'kartSonDort': i.kartSonDort,
        'girisId': i.girisId,
        'sonuc': i.basarili ? 'basarili' : 'hata',
        'aciklama': i.aciklama,
        'posSiparisNo': i.posSiparisNo,
        'uyeSiparisNo': i.uyeSiparisNo,
        'tutarMetni': i.tutarMetni,
        'tutarKurus': i.tutarKurus,
        'kaynak': i.kaynak.kod,
        'eslesme': i.eslesme.kod,
        'okunma': i.okunma == null ? null : Timestamp.fromDate(i.okunma!),
        'zaman': FieldValue.serverTimestamp(),
      });

  Query<Map<String, dynamic>> _gun(
    CollectionReference<Map<String, dynamic>> c,
    Gun gun,
    String? kullaniciId,
  ) {
    Query<Map<String, dynamic>> q = c;
    if (kullaniciId != null) q = q.where('kullaniciId', isEqualTo: kullaniciId);
    return q
        .where(
          'zaman',
          isGreaterThanOrEqualTo: Timestamp.fromDate(gun.baslangic),
        )
        .where('zaman', isLessThan: Timestamp.fromDate(gun.bitis))
        .orderBy('zaman')
        .limit(sinir);
  }

  @override
  Future<GunKayitlari> gun(Gun gun, {String? kullaniciId}) => _dene(() async {
    const kaynak = GetOptions(source: Source.server);
    final sonuc = await Future.wait([
      _gun(_girisler, gun, kullaniciId).get(kaynak),
      _gun(_islemler, gun, kullaniciId).get(kaynak),
    ]);
    if (sonuc.any((s) => s.docs.length >= sinir)) {
      throw const PosHatasi(
        'sinir',
        'Bu günün kayıtları liste sınırını aştı. Yöneticiyle görüşün.',
      );
    }
    return (
      girisler: [for (final d in sonuc[0].docs) girisOku(d.id, d.data())],
      islemler: [for (final d in sonuc[1].docs) islemOku(d.id, d.data())],
    );
  });
}

DateTime _zaman(Object? z) {
  if (z is Timestamp) return z.toDate();
  throw const PosHatasi('veri', 'Kayıt zamanı okunamadı.');
}

PosGirisi girisOku(String id, Map<String, dynamic> d) => PosGirisi(
  id: id,
  kullaniciId: d['kullaniciId'] as String,
  kullaniciAd: d['kullaniciAd'] as String,
  cariId: d['cariId'] as String,
  cariAd: d['cariAd'] as String,
  kimlikNo: d['kimlikNo'] as String,
  kartSonDort: d['kartSonDort'] as String,
  zaman: _zaman(d['zaman']),
);

/// 0.9.0 kayıtlarında `eslesme`/`okunma` yoktur: yer imi kaydı son girişe
/// bağlanmıştı. 0.10.1'den önceki başarısız kayıtların kimliği "-h" eksiz
/// numaradır; numara her zaman alandan okunur.
PosIslemi islemOku(String id, Map<String, dynamic> d) {
  final kaynak = IslemKaynagi.kodla(d['kaynak']) ?? IslemKaynagi.yerImi;
  final elle = kaynak == IslemKaynagi.elle;
  final okunma = d['okunma'];
  return PosIslemi(
    posSiparisNo: d['posSiparisNo'] as String,
    kullaniciId: d['kullaniciId'] as String,
    kullaniciAd: d['kullaniciAd'] as String,
    cariId: d['cariId'] as String,
    cariAd: d['cariAd'] as String,
    kimlikNo: d['kimlikNo'] as String,
    kartSonDort: d['kartSonDort'] as String,
    girisId: d['girisId'] as String,
    sonuc: d['sonuc'] == 'basarili' ? IslemSonucu.basarili : IslemSonucu.hata,
    aciklama: d['aciklama'] as String,
    uyeSiparisNo: d['uyeSiparisNo'] as String,
    tutarMetni: d['tutarMetni'] as String,
    kaynak: kaynak,
    eslesme:
        CariEslesmesi.kodla(d['eslesme']) ??
        (elle ? CariEslesmesi.elle : CariEslesmesi.sonGiris),
    okunma: okunma is Timestamp ? okunma.toDate() : null,
    zaman: _zaman(d['zaman']),
  );
}
