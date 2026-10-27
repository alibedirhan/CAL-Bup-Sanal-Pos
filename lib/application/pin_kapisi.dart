/// Uygulama PIN'inin ekranda sorulması (ekran kilidi olmayan Android telefon).
/// Kart kasası bağdaştırıcısı PIN'i buradan ister; açık uygulama ekranı
/// ([baglan]) pencereyi gösterir. Ekran yoksa PIN alınamaz (`null`).
enum PinTuru {
  /// İlk kartta yeni PIN belirlenir (iki kez).
  kur,

  /// Kayıtlı PIN sorulur.
  gir,
}

class PinIstegi {
  const PinIstegi(this.tur, {this.not});
  final PinTuru tur;

  /// Önceki denemenin sonucu (yanlış PIN, bekleme); `null`: ilk soru.
  final String? not;
}

typedef PinGosterici = Future<String?> Function(PinIstegi istek);

class PinKapisi {
  PinKapisi({required Future<void> Function() kapat}) : _kapat = kapat;
  final Future<void> Function() _kapat;
  PinGosterici? _gosterici;

  void baglan(PinGosterici g) => _gosterici = g;

  /// Yalnız kendisini bağlayan ekran ayırır (yeni ekran önce bağlanmış olabilir).
  void ayir(PinGosterici g) {
    if (_gosterici == g) _gosterici = null;
  }

  Future<String?> iste(PinIstegi istek) async => _gosterici?.call(istek);

  /// Uygulama kilitlendi veya çıkış: PIN yeniden sorulur.
  Future<void> kapat() async {
    try {
      await _kapat();
    } catch (_) {}
  }
}
