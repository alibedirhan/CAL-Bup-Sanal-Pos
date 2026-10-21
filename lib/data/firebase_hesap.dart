import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../application/hesap_portu.dart';
import '../domain/hata.dart';
import '../domain/kullanici.dart';
import 'firestore_esleme.dart';

class FirebaseHesap implements HesapPortu {
  FirebaseHesap(this.auth, this.db);
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  Future<void> hazirla() async {
    await auth.setLanguageCode('tr');
    if (kIsWeb) await auth.setPersistence(Persistence.SESSION);
  }

  @override
  String? get kimlik => auth.currentUser?.uid;
  @override
  Stream<String?> get degisimler => auth.authStateChanges().map((u) => u?.uid);
  Future<T> _dene<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 25));
    } on FirebaseAuthException catch (e) {
      throw hesapHatasi(e.code);
    } catch (e) {
      if (e is PosHatasi) rethrow;
      throw const PosHatasi(
        'baglanti',
        'Hesap sunucusuna ulaşılamadı. Bağlantınızı kontrol edin.',
      );
    }
  }

  @override
  Future<void> giris(String eposta, String parola) => _dene(() async {
    await auth.signInWithEmailAndPassword(
      email: eposta.trim(),
      password: parola,
    );
  });
  @override
  Future<void> cikis() => auth.signOut();
  @override
  Future<void> parolaSifirla(String eposta) =>
      _dene(() => auth.sendPasswordResetEmail(email: eposta.trim()));
  Future<void> yenidenDogrula(String parola) => _dene(() async {
    final u = auth.currentUser;
    if (u == null || u.email == null) {
      throw const PosHatasi('oturum', 'Yeniden giriş yapın.');
    }
    await u.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: u.email!, password: parola),
    );
  });
  @override
  Future<void> parolaDegistir(String mevcut, String yeni) => _dene(() async {
    if (yeni.length < 6 || yeni.length > 128) {
      throw const PosHatasi(
        'parola',
        '6–128 karakterlik bir şifre belirleyin.',
      );
    }
    await yenidenDogrula(mevcut);
    await auth.currentUser!.updatePassword(yeni);
  });
  @override
  Future<Kullanici> profil() async {
    final uid = kimlik;
    if (uid == null) throw const PosHatasi('oturum', 'Yeniden giriş yapın.');
    try {
      final d = await db
          .collection('kullanicilar')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return kullaniciOku(uid, d.data());
    } catch (e) {
      throw bulutHatasi(e);
    }
  }

  @override
  Stream<Kullanici?> profilIzle() {
    final uid = kimlik;
    if (uid == null) return Stream.value(null);
    return db
        .collection('kullanicilar')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map((d) {
          if (d.metadata.isFromCache) {
            throw const PosHatasi(
              'baglanti',
              'Erişim sunucuda doğrulanıyor. Bağlantınızı kontrol edin.',
            );
          }
          return kullaniciOku(uid, d.data());
        });
  }
}

PosHatasi hesapHatasi(String kod) => switch (kod) {
  'invalid-email' => const PosHatasi(
    'eposta',
    'Geçerli bir e-posta adresi yazın.',
  ),
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'user-disabled' => const PosHatasi(
    'giris',
    'Giriş yapılamadı. Bilgilerinizi kontrol edin veya yöneticiyle görüşün.',
  ),
  'too-many-requests' => const PosHatasi(
    'bekle',
    'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.',
  ),
  'weak-password' || 'password-does-not-meet-requirements' => const PosHatasi(
    'parola',
    'Şifre güvenlik koşullarını karşılamıyor. En az 6 karakter kullanın.',
  ),
  'email-already-in-use' => const PosHatasi(
    'hesap',
    'Bu e-posta için bir hesap zaten var. Erişim kayıtlarını kontrol edin.',
  ),
  'network-request-failed' => const PosHatasi(
    'baglanti',
    'İnternet bağlantısını kontrol edip yeniden deneyin.',
  ),
  _ => const PosHatasi('hesap', 'Hesap işlemi tamamlanamadı. Yeniden deneyin.'),
};
