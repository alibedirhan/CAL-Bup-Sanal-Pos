# Android uygulaması — kurulum, güncelleme ve yayın

Çalışanın gördüğü kurulum anlatımı indirme sayfasıdır
(`tools/indir/index.html` → https://bup-sanal-pos-indir.web.app/). Bu belge
yönetici ve geliştirici içindir.

## Çalışan için (özet)

1. Telefonda ekran kilidi (PIN/desen/şifre) önerilir. Yoksa (el terminali)
   ilk kartta 6 haneli uygulama PIN'i belirlenir (0.11.1; aşağıda).
2. İndirme sayfasından "Uygulamayı indir" → Chrome uyarısında "Yine de indir".
3. "Aç" → "Bilinmeyen uygulamalar" izni (yalnız Chrome için) → "Yükle".
4. Play Koruma uyarısı: "Ayrıntılar" → "Yine de yükle" (Play'siz dağıtım; normal).
5. Şirket e-postası ve şifresiyle giriş; sonra parmak izi/yüzle açılır.
6. Kartlar bir kez yeniden eklenir (web kartları telefona taşınmaz, bilinçli).

iPhone'a uygulama yoktur; iPhone web sürümünü kullanır.

## Ekran kilidi olmayan telefon: uygulama PIN'i (0.11.1)

Kullanıcı kararı (27 Ekim 2026; el terminali). Telefonda ekran kilidi varsa
değişen bir şey yok: kartlar telefon kilidine bağlı Keystore anahtarıyla
korunur. Kilit yoksa ilk kartta 6 haneli PIN belirlenir (111111, 123456 gibi
kolay PIN'ler reddedilir). Kart iki katmanla şifrelenir: PIN'den türetilen
anahtar (PBKDF2-HMAC-SHA256, 310 000 tur) ve telefona bağlı Keystore anahtarı.
PIN telefonda saklanmaz. Kart açılırken/doldurulurken PIN sorulur; uygulama
kilitlenene, çıkış yapılana veya 15 dk dolana kadar yeniden sorulmaz.
5. yanlıştan sonra 30 sn'den başlayıp katlanan bekleme, **10. yanlışta bu
telefondaki kart bilgileri silinir** (sunucudaki cariler/kart özetleri kalır,
kartlar yeniden eklenir). PIN unutulursa da çözüm kartları yeniden eklemektir.
Sınır: telefon kilidinden zayıftır (telefonun geri kalanı korumasızdır,
parmak iziyle açma olmaz, uygulama her açılışta hesap şifresini ister).
Kasa telefon kilidiyle kurulduktan sonra kilit kaldırılırsa kartlar açılmaz;
uygulama bunu söyler (kilidi geri aç ya da kartları silip yeniden ekle).

## Güncelleme nasıl çalışır

- Sunucudaki `ayarlar/android` belgesi: `enDusuk`, `son` (Android versionCode),
  `sonAd`, `indirme`, `sha256`. İstemci yazamaz; yalnız yayın betiği yazar.
- Uygulama açılışta ve kilit açılınca bakar (`lib/domain/surum.dart`):
  - sürüm < `enDusuk` → tam ekran "Güncelleme gerekli" (indir / çıkış). Kartlar
    ve bekleyen ödeme sonuçları telefonda kalır; yeni sürüm üstüne kurulunca
    kaldığı yerden devam eder.
  - sürüm < `son` → ana ekranda "Yeni sürüm hazır" notu.
  - belge okunamaz/bozuk/çevrimdışı → engellemez.
- Kendiliğinden kurulmaz: Play Store dışı uygulamayı Android sessizce
  güncellemeye izin vermez. Kişi bildirimdeki "İndir"e dokunur ve üstüne kurar.
  (MDM'li cihazlarda — ör. Zebra StageNow/EMM — yönetici sessiz kurabilir.)
- Güncelleme her zaman **üstüne kurulur**. Uygulamayı kaldırmak telefondaki
  kartları siler. Aynı imza anahtarı şarttır: anahtar kaybolursa telefonlar
  yeni sürümü kabul etmez (kaldırıp kurmak ve kartları yeniden eklemek gerekir).

## Yayın (geliştirici)

```
bash tools/android_yayin.sh                     # deneme: derle + denetle, yayın yok
bash tools/android_yayin.sh --yayinla           # kullanıcı onayıyla
bash tools/android_yayin.sh --yayinla --zorunlu # eski sürümleri kapat
```

Her yayından önce kullanıcıya sorulur. Betik sırasıyla:
1. Yapılandırma kapısı: `config/android.json` canlı proje, deneme/emülatör/taklit
   DenizPay yok; pubspec sürümü = ekrandaki sürüm (`lib/ui/ortak.dart`); imza
   anahtarı var. `--yayinla`'da: temiz ağaç, `main`, GitHub ile aynı.
2. `flutter pub get` + `flutter build apk --release` (`--no-pub` yok).
3. `tools/android_apk_denetle.py`: imza sertifikası SHA-256 sabit değer, v2
   imza, paket/versionCode/versionName, minSdk 28, hata ayıklama yok, yedek
   kapalı, düz HTTP kapalı (manifest + ağ güvenliği), dex'te test kodu yok,
   `libapp.so`'da emülatör adresi/demo proje yok, canlı proje ve DenizPay var.
4. `build/indir/index.html` (doldurulmuş kurulum sayfası) ve
   `build/android_surum/bup-sanal-pos-<sürüm>.apk`.
5. `--yayinla`: yayın kapısı (`yayin_oncesi.mjs`) → aynı etiketli GitHub sürümü
   varsa durur → Firestore kuralları → APK, açık
   `alibedirhan/bup-sanal-pos-android` deposunda `v<sürüm>` sürüm eki olur →
   indirilen ekin SHA-256'sı doğrulanır → `hosting:indir` (yalnız sayfa) →
   sayfanın bu sürümü ve eki gösterdiği doğrulanır → `ayarlar/android`
   (`android_surum_yaz.mjs`; sürüm geri alınamaz, `--zorunlu` yoksa önceki
   `enDusuk` korunur).

Web uygulaması ayrı yayınlanır (`tools/yayin.sh` → yalnız `hosting:web`).
İki site aynı Firebase projesindedir (`.firebaserc` hedefleri `web`, `indir`).

**APK neden GitHub'da:** Firebase Spark (ücretsiz) Hosting çalıştırılabilir
dosyaları (.apk) reddeder ("Executable files are forbidden on the Spark billing
plan", 27 Ekim 2026'daki ilk yayında görüldü). Billing kapalı kalacağı için
kullanıcı kararıyla APK, yalnız APK tutan açık GitHub deposunun sürüm ekidir
(kaynak kodu orada yoktur; APK'da sır yoktur, hesap olmadan kullanılamaz).
Kurulum sayfası Hosting'de kalır, uygulamadaki `indirme` adresi sayfadır.
Firebase'e `.apk` konmaz (`firebase.json` `ignore`). Ekleri değiştirmeyin:
yeni dosya = yeni sürüm numarası.

## Yöneticinin hesabında yapacakları

- **İmza anahtarı yedeği:** `~/.bup-sanal-pos/imza/` klasörü (anahtar + parola
  dosyası) bilgisayar dışında, güvenli iki yerde saklanmalı.
- **Android API anahtarı kısıtlaması:** Google Cloud Console → APIs & Services →
  Credentials → "Android key (auto created by Firebase)" → Application
  restrictions: Android apps → paket `com.bup.sanalpos`, SHA-1 parmak izi
  `3B:19:62:A5:43:45:FE:2B:58:7A:17:25:07:6A:E7:B4:91:CC:89:3C` (imza anahtarının
  SHA-1’i; Google bu kısıtta SHA-1 ister). API restrictions: Identity Toolkit,
  Token Service, Cloud Firestore.
