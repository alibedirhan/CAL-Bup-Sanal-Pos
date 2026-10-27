/// Parmak izi/yüzle açma kuralları (kullanıcı kararı, 27 Ekim 2026;
/// docs/ANDROID_PLANI.md §6.2). Biyometri yalnız ekran kilidini açar; hesap
/// yetkisi yine sunucuda denetlenir. Hesap şifresi şu durumlarda istenir: hiç
/// şifre girilmemiş (ilk giriş/çıkış sonrası), telefon yeniden başlamış, son
/// şifreden bu yana [sifreAraligi] geçmiş veya saat geri alınmış. Telefona yeni
/// parmak izi/yüz eklenmesi cihaz anahtarını geçersiz kılar (bağdaştırıcıda).
class BiyometriKaydi {
  const BiyometriKaydi({
    required this.uid,
    required this.sonSifre,
    required this.acilis,
  });
  final String uid;

  /// Hesap şifresinin bu telefonda son doğrulandığı an.
  final DateTime sonSifre;

  /// O anda telefonun açılış sayacı (yeniden başlatmada artar).
  final int acilis;

  static const sifreAraligi = Duration(days: 7);

  /// Biyometriyle açmaya izin var mı; yoksa hesap şifresi istenir.
  bool gecerli({
    required String uid,
    required DateTime simdi,
    required int acilis,
  }) {
    final gecen = simdi.difference(sonSifre);
    return this.uid == uid &&
        this.acilis == acilis &&
        !gecen.isNegative &&
        gecen < sifreAraligi;
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'uid': uid,
    'sonSifre': sonSifre.millisecondsSinceEpoch,
    'acilis': acilis,
  };

  /// Bozuk veya tanınmayan kayıt `null` olur: biyometri kapalı sayılır, şifre istenir.
  static BiyometriKaydi? fromJson(Object? d) {
    if (d is! Map ||
        d.length != 4 ||
        d['v'] != 1 ||
        d['uid'] is! String ||
        (d['uid'] as String).isEmpty ||
        (d['uid'] as String).length > 128 ||
        d['sonSifre'] is! int ||
        d['acilis'] is! int) {
      return null;
    }
    return BiyometriKaydi(
      uid: d['uid'] as String,
      sonSifre: DateTime.fromMillisecondsSinceEpoch(d['sonSifre'] as int),
      acilis: d['acilis'] as int,
    );
  }
}
