/// Kullanıcıya gösterilebilen, hassas girdi içermeyen alan hatası.
class PosHatasi implements Exception {
  const PosHatasi(this.kod, this.mesaj);
  final String kod;
  final String mesaj;
  @override
  String toString() => mesaj;
}
