import 'package:cloud_firestore/cloud_firestore.dart';
import '../application/surum_denetimi.dart';

/// `ayarlar/android`: üyeler okur, yalnız yönetici aracı yazar (firestore.rules).
class FirestoreSurumAyari implements SurumAyariPortu {
  const FirestoreSurumAyari(this.db);
  final FirebaseFirestore db;
  @override
  Future<Object?> oku() async =>
      (await db.collection('ayarlar').doc('android').get()).data();
}
