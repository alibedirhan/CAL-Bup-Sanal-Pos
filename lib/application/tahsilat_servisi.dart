import 'dart:math';
import '../domain/acik_giris.dart';
import '../domain/bekleyen_sonuc.dart';
import '../domain/gun_sonu.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import '../domain/tahsilat.dart';

/// Giriş ve işlem kayıtları. Canlı adaptörde kayıtlar yalnız eklenir;
/// değiştirme/silme sunucu kuralıyla kapalıdır, zaman sunucu saatidir.
abstract interface class IslemDeposu {
  Future<void> girisKaydet(PosGirisi giris);

  /// Aynı kimlikte ([PosIslemi.kimlik]) kayıt varsa yazmaz, mevcut kaydı
  /// döndürür (`zatenVardi`). Yazma reddedilip kayıt o arada oluştuysa da öyle.
  Future<IslemKaydi> islemKaydet(PosIslemi islem);

  /// `kullaniciId` yoksa herkesin kayıtları (yalnız yönetici okuyabilir).
  Future<GunKayitlari> gun(Gun gun, {String? kullaniciId});
}

typedef GunKayitlari = ({List<PosGirisi> girisler, List<PosIslemi> islemler});

/// Bu cihazda açılan DenizPay girişleri; sonuç ekranındaki yer iminin açtığı
/// sayfa okur. Eşzamanlıdır (tıklamada, DenizPay açılmadan önce yazılır).
abstract interface class AcikGirisPortu {
  bool get destekli;
  void ekle(AcikGiris acik);
  void temizle();
}

/// Gün sonu dosyasını telefona/bilgisayara indirir.
abstract interface class DosyaIndirici {
  bool get destekli;
  void indir(String dosyaAdi, String icerik);
}

/// DenizPay sonuç ekranından okunup bu cihazda bekleyen sonuçlar. Ham kayıtlar
/// döner; doğrulama domain'dedir. `yanitla` sonucu açık sonuç sayfasına bildirir.
/// Kayıtlar [PosIslemi.kimlik] ile anılır (başarısız denemede "-h" ekli).
abstract interface class SonucKutusu {
  bool get destekli;
  List<Map<String, Object?>> oku();
  void sil(String kimlik);
  void yanitla(String kimlik, {required bool tamam, required String mesaj});

  /// Başka sekmede sonuç eklendiğinde tetiklenir.
  Stream<void> get degisimler;
}

class KapaliSonucKutusu implements SonucKutusu {
  const KapaliSonucKutusu();
  @override
  bool get destekli => false;
  @override
  List<Map<String, Object?>> oku() => const [];
  @override
  void sil(String kimlik) {}
  @override
  void yanitla(String kimlik, {required bool tamam, required String mesaj}) {}
  @override
  Stream<void> get degisimler => const Stream.empty();
}

/// Bekleyen bir sonucun yazılma sonucu; ekranda kısa not olarak gösterilir.
class KutuSonucu {
  const KutuSonucu(this.mesaj, {required this.tamam});
  final String mesaj;
  final bool tamam;
}

class KapaliAcikGiris implements AcikGirisPortu {
  const KapaliAcikGiris();
  @override
  bool get destekli => false;
  @override
  void ekle(AcikGiris acik) {}
  @override
  void temizle() {}
}

class KapaliDosyaIndirici implements DosyaIndirici {
  const KapaliDosyaIndirici();
  @override
  bool get destekli => false;
  @override
  void indir(String dosyaAdi, String icerik) =>
      throw const PosHatasi('indir', 'Bu cihazda dosya indirilemiyor.');
}

/// Tahsilat kayıtları ve gün sonu. Flutter, Firebase ve tarayıcı bilmez.
class TahsilatServisi {
  TahsilatServisi({
    required this.depo,
    required this.kullaniciId,
    required this.kullaniciAdi,
    this.acikGiris = const KapaliAcikGiris(),
    this.indirici = const KapaliDosyaIndirici(),
    this.kutu = const KapaliSonucKutusu(),
    DateTime Function()? saat,
    Random? rastgele,
  }) : saat = saat ?? DateTime.now,
       _rastgele = rastgele ?? Random.secure();
  final IslemDeposu depo;
  final String kullaniciId, kullaniciAdi;
  final AcikGirisPortu acikGiris;
  final DosyaIndirici indirici;
  final SonucKutusu kutu;
  final DateTime Function() saat;
  final Random _rastgele;
  bool _isleniyor = false, _tekrar = false;

  Gun get bugun => Gun.ani(saat());

  /// Tıklamada eşzamanlı çağrılır: DenizPay açılmadan önce giriş bu cihazın
  /// açık girişlerine eklenir (öncekiler silinmez; sonuç sayfası sonucu firma
  /// numarasıyla doğru girişe bağlar). Sunucu kaydı ayrıca [girisKaydet] ile.
  PosGirisi girisHazirla(DenemeSonucu sonuc) {
    final giris = PosGirisi(
      id: _kimlik(),
      kullaniciId: kullaniciId,
      kullaniciAd: kullaniciAdi,
      cariId: sonuc.cariId,
      cariAd: sonuc.cariAdi,
      kimlikNo: sonuc.kimlikNo,
      kartSonDort: sonuc.kart?.sonDort ?? '',
    );
    if (acikGiris.destekli) {
      try {
        acikGiris.ekle(AcikGiris(giris, saat()));
      } catch (_) {
        // İşaret yazılamazsa DenizPay yine açılır; sonuç elle kaydedilebilir.
      }
    }
    return giris;
  }

  Future<void> girisKaydet(PosGirisi giris) => depo.girisKaydet(giris);

  /// Elle girilen DenizPay girişi hangi cari olduğu bilinmez; o andan sonra
  /// okunan sonuç önceki girişlerin hiçbirine kendiliğinden bağlanmasın.
  void acikGirisiTemizle() {
    try {
      acikGiris.temizle();
    } catch (_) {}
  }

  /// DenizPay sonuç ekranına bakarak elle kayıt. Tutar açık olmalıdır.
  Future<IslemKaydi> elleKaydet({
    required Cari cari,
    required IslemSonucu sonuc,
    required String posSiparisNo,
    required String tutarMetni,
    String aciklama = '',
    String kartSonDort = '',
  }) async {
    if (cari.kimlikNo.isEmpty) {
      throw const PosHatasi(
        'kimlik',
        'Bu carinin VKN / TC numarası yok. Önce cariyi düzenle.',
      );
    }
    if (tutarCoz(tutarMetni) == null) {
      throw const PosHatasi(
        'tutar',
        'Tutarı DenizPay ekranındaki gibi yaz (ör. 4500 veya 45678,90).',
      );
    }
    final neden = aciklama.trim();
    if (sonuc == IslemSonucu.hata && neden.isEmpty) {
      throw const PosHatasi(
        'aciklama',
        'Hata ekranındaki açıklamayı yaz (ör. 3D Şifresi Yanlış).',
      );
    }
    return _kaydet(
      PosIslemi(
        posSiparisNo: posNoDuzelt(posSiparisNo),
        kullaniciId: kullaniciId,
        kullaniciAd: kullaniciAdi,
        cariId: cari.id,
        cariAd: cari.ad,
        kimlikNo: cari.kimlikNo,
        sonuc: sonuc,
        aciklama: neden.isNotEmpty ? neden : 'Ödeme başarılı (elle kaydedildi)',
        tutarMetni: tutarMetni.trim(),
        kaynak: IslemKaynagi.elle,
        eslesme: CariEslesmesi.elle,
        kartSonDort: kartSonDort,
      ),
    );
  }

  /// Var olan kayıt istenenle aynı ödeme değilse [IslemKaydi.farkli].
  Future<IslemKaydi> _kaydet(PosIslemi i) async {
    final k = await depo.islemKaydet(i);
    return k.zatenVardi && !ayniOdeme(k.islem, i)
        ? IslemKaydi(k.islem, zatenVardi: true, farkli: true)
        : k;
  }

  /// Bu cihazda bekleyen sonuçları yazar. Sonuç kutudan yalnız sunucuda kaydı
  /// olduğu görülünce çıkar: bağlantı, oturum veya yetki sorununda telefonda
  /// kalır, her açılışta yeniden denenir ve kişiye söylenir. Başka hesabın
  /// sonucuna dokunulmaz.
  Future<List<KutuSonucu>> kutuyuIsle() async {
    if (!kutu.destekli) return const [];
    if (_isleniyor) {
      _tekrar = true;
      return const [];
    }
    _isleniyor = true;
    final sonuclar = <KutuSonucu>[];
    try {
      do {
        _tekrar = false;
        for (final j in kutu.oku()) {
          final b = BekleyenSonuc.oku(j, kullaniciAdi);
          if (b == null) {
            // JS ve Dart aynı biçimi denetler; buraya düşmemeli. Yine de silinmez.
            if (j['uid'] == kullaniciId) sonuclar.add(_okunamadi(j));
            continue;
          }
          if (b.kullaniciId != kullaniciId) continue;
          final s = await _yaz(b);
          sonuclar.add(s.$1);
          if (!s.$2) return sonuclar; // bağlantı yok: sonrakiler de bekler
        }
      } while (_tekrar);
      return sonuclar;
    } finally {
      _isleniyor = false;
    }
  }

  KutuSonucu _okunamadi(Map<String, Object?> j) {
    final no = j['posSiparisNo'], ad = j['cariAd'];
    return KutuSonucu(
      'Bu telefonda bekleyen bir DenizPay sonucu okunamadı'
      '${ad is String ? ' ($ad${no is String ? ' · Pos No $no' : ''})' : ''}. '
      'Telefonda tutuluyor; cari profilinden elle kaydet ve yöneticine bildir.',
      tamam: false,
    );
  }

  /// Sonuç notu ve devam edilip edilmeyeceği (bağlantı yoksa `false`).
  Future<(KutuSonucu, bool)> _yaz(BekleyenSonuc b) async {
    final no = b.islem.posSiparisNo, kimlik = b.islem.kimlik;
    final IslemKaydi k;
    try {
      k = await _kaydet(b.islem);
    } catch (e) {
      // Beklenmeyen hata da geçici sayılır: sonuç silinmez.
      final kod = e is PosHatasi ? e.kod : '';
      final kalici = const {'yetki', 'pos_no_baska'}.contains(kod);
      final s = KutuSonucu(
        kalici
            ? 'Kaydedilemedi: ${b.islem.cariAd} · Pos No $no. '
                  '${kod == 'yetki' ? 'Cari sana atanmamış, VKN değişmiş ya da oturum yenilenmeli.' : (e as PosHatasi).mesaj} '
                  'Sonuç bu telefonda tutuluyor; sorun giderilince kendiliğinden kaydedilir. Yöneticine bildir.'
            : 'DenizPay sonucu (${b.islem.cariAd} · Pos No $no) bu telefonda '
                  'bekliyor; kaydedilemedi, bağlantı gelince yeniden denenecek.',
        tamam: false,
      );
      kutu.yanitla(kimlik, tamam: false, mesaj: s.mesaj);
      return (s, kalici);
    }
    // Sunucuda kayıt var (yeni veya önceden): telefondaki kopya artık gereksiz.
    final s = _kayitNotu(k, b);
    kutu.sil(kimlik);
    kutu.yanitla(kimlik, tamam: s.tamam, mesaj: s.mesaj);
    return (s, true);
  }

  KutuSonucu _kayitNotu(IslemKaydi k, BekleyenSonuc b) {
    final i = k.islem;
    if (k.zatenVardi) {
      // Aynı numarada başka cari veya tutar varsa sessizce "tamam" denmez.
      if (!k.farkli) {
        return KutuSonucu(
          'Bu ödeme zaten kayıtlı: ${i.cariAd} · ${saatYaz(i.zaman!)}.',
          tamam: true,
        );
      }
      final yeni = b.islem;
      return KutuSonucu(
        'Dikkat: Pos No ${i.posSiparisNo} (${i.basarili ? 'başarılı' : 'başarısız'}) '
        'zaten ${i.cariAd} · ${_tutar(i)} olarak kayıtlı (${saatYaz(i.zaman!)}). '
        'Okunan sonuç farklı: ${yeni.cariAd} · ${_tutar(yeni)}. Kaydedilmedi; '
        'DenizPay ekranını kontrol edip yöneticine bildir.',
        tamam: false,
      );
    }
    // Gün sunucu saatidir: sonuç dün okunup bugün yazıldıysa açıkça söylenir.
    final okunan = Gun.ani(b.okunma), yazilan = Gun.ani(i.zaman!);
    final gunNotu = okunan == yazilan
        ? ''
        : ' Sonuç ${okunan.etiket} ${saatYaz(b.okunma)}’de okunmuştu; '
              '${yazilan.etiket} gün sonuna yazıldı.';
    return KutuSonucu(
      'Kaydedildi: ${i.cariAd} · ${_tutar(i)} · '
      '${i.basarili ? 'başarılı' : 'başarısız'} · ${saatYaz(i.zaman!)}.$gunNotu',
      tamam: true,
    );
  }

  static String _tutar(PosIslemi i) =>
      i.tutarKurus == null ? i.tutarMetni : tutarYaz(i.tutarKurus!);

  /// Gelecek gün istenmez; geçmiş günler kayıtlar değişmediği için kesindir.
  Future<GunSonu> gunSonu(Gun gun, {bool herkes = false}) async {
    if (gun.compareTo(bugun) > 0) {
      throw const PosHatasi('gun', 'Henüz gelmemiş bir günün gün sonu olmaz.');
    }
    final k = await depo.gun(gun, kullaniciId: herkes ? null : kullaniciId);
    return GunSonu.hesapla(gun, k.girisler, k.islemler);
  }

  void disaAktar(GunSonu gunSonu) => indirici.indir(
    'gun-sonu-${gunSonu.gun.anahtar}.csv',
    gunSonuCsv(gunSonu),
  );

  static const _harfler =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  String _kimlik() => String.fromCharCodes(
    List.generate(
      20,
      (_) => _harfler.codeUnitAt(_rastgele.nextInt(_harfler.length)),
    ),
  );
}
