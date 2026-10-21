import 'modeller.dart';

class Kullanici {
  Kullanici({
    required this.id,
    required String ad,
    required this.eposta,
    required this.yonetici,
    required this.aktif,
  }) : ad = duzMetin(ad, enAz: 2, enFazla: 80);
  final String id, ad, eposta;
  final bool yonetici, aktif;
}
