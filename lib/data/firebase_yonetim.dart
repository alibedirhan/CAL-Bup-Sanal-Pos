import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import '../domain/kullanici.dart';
import '../domain/modeller.dart';
import 'firebase_hesap.dart';
import 'firestore_deposu.dart';
import 'firestore_esleme.dart';

class FirebaseYonetim implements YonetimPortu {
  FirebaseYonetim(this.auth, this.db, {this.emulator = false});
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final bool emulator;
  @override
  Future<List<CariOzeti>> cariler() async {
    try {
      final s = await db
          .collection('cariler')
          .where('silindi', isEqualTo: false)
          .limit(1000)
          .get(const GetOptions(source: Source.server));
      return s.docs.map((d) {
        final p = cariOku(d.id, d.data());
        return CariOzeti(p.cari, p.kartlar.length);
      }).toList();
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Future<List<Kullanici>> kullanicilar() async {
    try {
      final d = await db
          .collection('kullanicilar')
          .limit(300)
          .get(const GetOptions(source: Source.server));
      return d.docs.map((x) => kullaniciOku(x.id, x.data())).toList();
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Future<void> hesapAc(String ad, String eposta, String geciciParola) async {
    if (geciciParola.length < 6 || geciciParola.length > 128) {
      throw const PosHatasi(
        'parola',
        '6–128 karakterlik bir şifre belirleyin.',
      );
    }
    final app = await Firebase.initializeApp(
      name: 'hesap-${DateTime.now().microsecondsSinceEpoch}',
      options: auth.app.options,
    );
    final ikincil = FirebaseAuth.instanceFor(app: app);
    User? yeni;
    try {
      if (emulator) {
        await ikincil.useAuthEmulator(
          const String.fromEnvironment(
            'BUP_EMULATOR_HOST',
            defaultValue: '127.0.0.1',
          ),
          9098,
        );
      }
      if (kIsWeb) await ikincil.setPersistence(Persistence.NONE);
      yeni = (await ikincil.createUserWithEmailAndPassword(
        email: eposta.trim(),
        password: geciciParola,
      )).user!;
      final k = Kullanici(
        id: yeni.uid,
        ad: ad,
        eposta: eposta.trim().toLowerCase(),
        yonetici: false,
        aktif: true,
      );
      await db.collection('kullanicilar').doc(k.id).set({
        'ad': k.ad,
        'eposta': k.eposta,
        'yonetici': false,
        'aktif': true,
        'olusturma': FieldValue.serverTimestamp(),
        'guncelleme': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Profil yoksa erişim yoktur. Yarım kalan yeni Auth hesabını da temizle.
      try {
        await yeni?.delete();
      } catch (_) {
        /* Profil yok: veriye erişemez. */
      }
      throw e is FirebaseAuthException ? hesapHatasi(e.code) : bulutHatasi(e);
    } finally {
      await ikincil.signOut();
      await app.delete();
    }
  }

  @override
  Future<void> erisimDegistir(Kullanici k, bool aktif) async {
    try {
      await db.collection('kullanicilar').doc(k.id).update({
        'aktif': aktif,
        'guncelleme': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Future<void> ata(String cariId, int surum, String yeniSahip) =>
      FirestoreDeposu(db).ata(auth.currentUser!.uid, cariId, surum, yeniSahip);
}
