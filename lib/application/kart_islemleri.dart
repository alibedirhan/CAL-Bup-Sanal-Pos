import 'kart_kasasi.dart';
import 'portlar.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/kart_bilgileri.dart';

class KartIslemleri {
  const KartIslemleri(this.depo, this.kasa, this.uid);
  final CariDeposu depo;
  final KartKasasi kasa;
  final String uid;
  Future<KartKayitSonucu> kaydet(
    Cari cari,
    KartOzeti kart,
    KartBilgileri? bilgiler,
    DateTime simdi,
  ) async {
    kartEtiketi(kart.ad);
    if (kart.cariId != cari.id) {
      throw const PosHatasi('kart', 'Kart cariye ait değil.');
    }
    // Eski özetlerin düzenlenmesi geriye uyumludur. Yeni tam kart geçmiş olamaz.
    if (bilgiler != null && kart.suresiGecti(simdi)) {
      final eski = (await depo.profil(
        uid,
        cari.id,
      )).kartlar.where((k) => k.id == kart.id).firstOrNull;
      if (eski == null ||
          eski.ay != kart.ay ||
          eski.yil != kart.yil ||
          eski.sonDort != kart.sonDort) {
        throw const PosHatasi('gecmis', 'Süresi geçmiş yeni kart eklenemez.');
      }
    }
    var sonuc = kart;
    if (bilgiler != null) {
      if (bilgiler.sonDort != kart.sonDort) {
        throw const PosHatasi('kart', 'Kart bilgileri eşleşmiyor.');
      }
      // Önce şifreli taslak: yazma hatası eski yerel kaydı ezmez. Belirsiz
      // yazmada taslak korunur, sunucudaki opak referansla geri alınabilir.
      sonuc = kart.cihazKaydiyla(await kasa.hazirla(uid, kart, bilgiler));
    }
    await depo.kartKaydet(uid, cari.id, cari.surum, sonuc);
    if (bilgiler != null) {
      try {
        await kasa.tamamla(uid, sonuc.cihazKayitId!);
      } catch (_) {
        return KartKayitSonucu(
          sonuc,
          uyari:
              'Kart kaydedildi. Cihazdaki son adım tamamlanamadı; kartı tekrar açarak yeniden dene. Uygulama veya tarayıcı verilerini silme.',
        );
      }
    }
    return KartKayitSonucu(sonuc);
  }

  Future<KartBilgileri?> oku(KartOzeti kart, bool Function() oturumAcik) async {
    final p = await depo.profil(uid, kart.cariId);
    final guncel = p.kartlar.where((k) => k.id == kart.id).firstOrNull;
    if (!oturumAcik()) {
      throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden giriş yap.');
    }
    if (guncel == null ||
        guncel.cihazKayitId != kart.cihazKayitId ||
        guncel.sonDort != kart.sonDort ||
        guncel.ay != kart.ay ||
        guncel.yil != kart.yil) {
      throw const PosHatasi(
        'surum',
        'Kart bilgisi değişti. Güncel kaydı yeniden aç.',
      );
    }
    final sonuc = await kasa.oku(uid, guncel);
    if (!oturumAcik()) {
      throw const PosHatasi('kilit', 'Ekran kilitlendi. Yeniden giriş yap.');
    }
    return sonuc;
  }

  Future<String?> temizle(String cariId, String? kartId) async {
    try {
      await kasa.sil(uid, cariId, kartId);
      return null;
    } catch (_) {
      return 'Kayıt sunucudan kaldırıldı; bu cihazdaki şifreli kopya temizlenemedi. Uygulamayı yeniden açıp kartı tekrar silmeyi dene.';
    }
  }
}
