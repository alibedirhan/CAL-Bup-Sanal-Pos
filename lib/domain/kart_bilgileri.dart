import 'hata.dart';
import 'modeller.dart';

String kartEtiketi(String deger) {
  final ad = duzMetin(deger, enAz: 2, enFazla: 60);
  if (RegExp(r'[0-9][0-9 -]{10,}[0-9]').hasMatch(ad)) {
    throw const PosHatasi(
      'etiket',
      'Kart adı alanına kart numarası veya telefon yazma.',
    );
  }
  return ad;
}

String kartNumarasi(String deger) {
  if (deger.length > 32) {
    throw const PosHatasi('numara', 'Kart numarasını kontrol et.');
  }
  final n = deger.replaceAll(' ', '');
  if (!RegExp(r'^[0-9]{12,19}$').hasMatch(n) || RegExp(r'^0+$').hasMatch(n)) {
    throw const PosHatasi('numara', 'Kart numarası 12–19 rakam olmalı.');
  }
  var toplam = 0;
  var iki = false;
  for (var i = n.length - 1; i >= 0; i--, iki = !iki) {
    var d = int.parse(n[i]);
    if (iki) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    toplam += d;
  }
  if (toplam % 10 != 0) {
    throw const PosHatasi(
      'numara',
      'Kart numarası kontrolü geçmedi. Rakamları kontrol et.',
    );
  }
  return n;
}

String kartTelefonu(String deger) {
  if (deger.trim().isEmpty) return '';
  if (deger.length > 24 || !RegExp(r'^[+0-9 ()-]+$').hasMatch(deger)) {
    throw const PosHatasi('telefon', 'Telefonu 05xx xxx xx xx biçiminde yaz.');
  }
  var n = deger.replaceAll(RegExp(r'[ ()-]'), '');
  if (RegExp(r'^05[0-9]{9}$').hasMatch(n)) n = '+90${n.substring(1)}';
  if (RegExp(r'^5[0-9]{9}$').hasMatch(n)) n = '+90$n';
  if (!RegExp(r'^\+905[0-9]{9}$').hasMatch(n)) {
    throw const PosHatasi(
      'telefon',
      'Türkiye cep telefonunu 05xx xxx xx xx biçiminde yaz.',
    );
  }
  return n;
}

/// Yalnız cihaz kasasına gider. Firebase/URL/günlük modellerine eklenmez.
class KartBilgileri {
  KartBilgileri({
    required String numara,
    String sahibi = '',
    String telefon = '',
  }) : numara = kartNumarasi(numara),
       sahibi = duzMetin(sahibi, enAz: 0, enFazla: 120),
       telefon = kartTelefonu(telefon);
  final String numara, sahibi, telefon;
  String get sonDort => numara.substring(numara.length - 4);
}
