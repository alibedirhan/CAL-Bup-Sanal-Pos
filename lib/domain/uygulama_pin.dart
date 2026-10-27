/// Uygulama PIN'i: ekran kilidi olmayan Android telefonda kart kasasını korur
/// (kullanıcı kararı, 27 Ekim 2026). Kotlin `PinKasasi` yalnız 6 rakamı ayrıca
/// denetler; tahmini kolay PIN'ler burada, belirlerken reddedilir.
abstract final class UygulamaPin {
  static const uzunluk = 6;

  /// Yalnız biçim (girişte): 6 rakam.
  static bool bicimli(String pin) => RegExp(r'^[0-9]{6}$').hasMatch(pin);

  /// Yeni PIN için hata metni; uygunsa `null`.
  static String? yeniPinHatasi(String pin, String tekrar) {
    if (!bicimli(pin)) return 'PIN 6 rakam olmalı.';
    final r = pin.codeUnits;
    final ayni = r.every((c) => c == r.first);
    bool sirali(int adim) => [
      for (var i = 1; i < r.length; i++) r[i] - r[i - 1],
    ].every((f) => f == adim);
    if (ayni || sirali(1) || sirali(-1)) {
      return 'Tahmini kolay PIN seçme (ör. 111111, 123456).';
    }
    if (pin != tekrar) return 'İki PIN aynı değil.';
    return null;
  }
}
