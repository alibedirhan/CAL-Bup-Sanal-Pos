import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/kart_bilgileri.dart';

abstract interface class KartKasasi {
  Future<String> hazirla(String uid, KartOzeti kart, KartBilgileri bilgiler);
  Future<void> tamamla(String uid, String kayitId);
  Future<KartBilgileri?> oku(String uid, KartOzeti kart);
  Future<void> sil(String uid, String cariId, String? kartId);
}

class KapaliKartKasasi implements KartKasasi {
  const KapaliKartKasasi();
  Never _kapali() => throw const PosHatasi(
    'cihaz',
    'Bu ortamda cihaz kart kasası kullanılamıyor.',
  );
  @override
  Future<String> hazirla(
    String uid,
    KartOzeti kart,
    KartBilgileri bilgiler,
  ) async => _kapali();
  @override
  Future<void> tamamla(String uid, String kayitId) async => _kapali();
  @override
  Future<KartBilgileri?> oku(String uid, KartOzeti kart) async => null;
  @override
  Future<void> sil(String uid, String cariId, String? kartId) async {}
}

class KartKayitSonucu {
  const KartKayitSonucu(this.kart, {this.uyari});
  final KartOzeti kart;
  final String? uyari;
}
