# Android uygulaması planı — 27 Ekim 2026

Kullanıcı isteği (27 Ekim): Sanal POS'un Flutter ile Android uygulaması olması;
"dikkatli, titiz, aynı özende; sağlam temelli, sürdürülebilir, mimarisi kusursuz;
kurumsal bir firma için". Önce plan, onaydan sonra uygulama. Bu karar 21 Ekim'deki
"yerel Android uygulaması yazılmaz" kararını Android için kaldırır (iPhone için
web sürümü ve Apple kararı aynen sürer). Play Store'a gönderme kararı aşağıda
açık sorudur; öneri Play'siz imzalı APK.

## 1. Mevcut durumun incelemesi (özet)

- Katmanlar temiz: `domain` ve `application` Flutter/Firebase/tarayıcı bilmez
  (`test/mimari_test.dart` zorlar). Tarayıcıya bağlı her şey altı port arkasında:
  | Port | Web'de bugün | Android'de |
  | --- | --- | --- |
  | `KartKasasi` | Web Crypto + IndexedDB (`kart_kasasi.js`) | Android Keystore AES-GCM, uygulamaya özel dosya |
  | `PosGirisKapisi` | gizli form POST, yeni sekme (`pos_giris.js`) | uygulama içi DenizPay ekranında POST |
  | `DoldurmaHazirligi` | localStorage işi + yer imi + `doldur.html` | gerekmez: uygulama kartı kendi ekranına yazar |
  | `AcikGirisPortu` | son 10 giriş, localStorage | gerekmez/basit: hangi cariyle açıldığı kesin bilinir |
  | `SonucKutusu` | localStorage, sekmeler arası | şifreli kalıcı bekleyen sonuç kutusu (internet yoksa) |
  | `DosyaIndirici` | tarayıcı indirmesi | Android paylaş/kaydet penceresi |
- Firebase oturumu webde yalnız sekmede (`Persistence.SESSION`); Android'de bu
  seçenek yok, oturum kalıcıdır → uygulama her açılışta kilitli açılmalı (§4.5).
- Sonuç okuma (`sonuc_coz.js`) ve cari eşleştirme (`cari_eslestir.js`) yalnız JS'tedir.
  Tutar okuma Dart'ta da var (`domain/tahsilat.dart`), iki taraf ortak örnek
  dosyasıyla sınanıyor (`test/veri/tahsilat_ornekleri.json`).
- Kural dosyası `posIslemleri` için `kaynak` (`elle`/`yer_imi`) ve `eslesme`
  değerlerini sabit listeyle kabul eder; Android kaydı için yeni değer gerekir.
- `android/` klasörü Flutter iskeleti: paket adı `com.bup.bup_sanal_pos`, release
  hata ayıklama anahtarıyla imzalanıyor, güvenlik ayarı yok. Firebase projesinde
  yalnız WEB uygulaması kayıtlı. Bilgisayarda Flutter 3.41.2, Android SDK 36,
  Java 21, KVM ve Android 16 emülatör görüntüsü var; AVD yok, lisanslar onaysız.

## 2. Hedef mimari

Tek kod tabanı, iki hedef: **Web** (iPhone ve bilgisayar; bugünkü gibi) ve
**Android** (yeni). İş kuralları, ekranlar, Firebase deposu ve sunucu kuralları
ortaktır; yalnız port bağdaştırıcıları ve bileşim platforma göre seçilir.

```
lib/
  domain/        saf kurallar (+ sonuç okuma ve uygulama içi eşleşme, Dart)
  application/   servisler ve portlar (+ DenizPayOturumu portu)
  data/          ortak: Firestore/Auth bağdaştırıcıları
  data/web/      bugünkü web bağdaştırıcıları (taşınır, davranış aynı)
  data/android/  yeni Android bağdaştırıcıları
  ui/            ortak ekranlar (+ ui/denizpay/ uygulama içi DenizPay ekranı)
  bilesim/       platforma göre bağdaştırıcı seçimi (web / android / kapalı)
android/app/src/main/kotlin/…/  Keystore kart kasası, ekran güvenliği (küçük, test edilir)
```

- Seçim derleme anında koşullu içe aktarmayla yapılır (`dart.library.js_interop`
  → web, `dart.library.io` → Android). Web paketine Android eklentisi, Android
  paketine `web/` JS'leri girmez. Mimari test bunu ve "ui somut depo bilmez"
  kuralını Android için de denetler.
- **Ödünleşim:** sonuç okuma kuralları Dart'a da yazılır (Android Dart'ta okur,
  web JS'te). İki kopya, tek örnek dosyasıyla birebir sınanır (projede tutar
  okuma için kullanılan yöntem). Alternatif (JS'i WebView'da çalıştırmak) tek
  kopya olurdu ama sonucu banka sayfasının içinde, o sayfanın betikleriyle aynı
  ortamda üretirdi; güvenilirlik için reddedildi.
- Yeni bağımlılıklar yalnız birinci taraf/yaygın ve sürümü sabit paketler:
  `webview_flutter` (Flutter ekibi), `share_plus` (paylaşım), gerekirse
  AndroidX Biometric (Google). Kart kasası ve biyometrik kilit için üçüncü taraf
  paket kullanılmaz: küçük, test edilen kendi Kotlin kodumuz doğrudan Android
  Keystore'u kullanır (denetlenebilir, bağımlılık riski yok).

## 3. Uygulama içi DenizPay akışı (asıl kazanım)

Web'de DenizPay ayrı sekmede açılıyor, kart ve sonuç yer imleriyle taşınıyor.
Android'de DenizPay uygulamanın içinde açılır; yer imi, açılır pencere, sekme
eşleştirmesi ve "hangi cari?" belirsizliği ortadan kalkar.

1. Cari (+ isteğe bağlı kart) seçilir, açık onay → "DenizPay'e giriş yap".
2. Uygulama önceki DenizPay çerezlerini/önbelleğini **siler**, sonra sabit
   `login.aspx` adresine aynı alanlarla POST yapar. Böylece açılan DenizPay
   oturumu kesinlikle bu cariye aittir (webde doğrulanamayan "eski sekme"
   sorununun kökten çözümü).
3. Ekranın üstünde sabit şerit: cari adı, VKN/TC, açık sayfanın alan adı (kilit
   simgesiyle), "Kapat". Kullanıcı hangi sitede olduğunu her an görür.
4. Kart sayfasında "Kartı doldur" düğmesi belirir. Yalnız: sayfa DenizPay
   kökeninde, "Firma İsmi" numarası seçili cariyle aynı, kutular bugünkü
   kurallarla (`number`/`name`/`expiry`, engel listesi) tek ve görünür. Yalnız
   numara, ad, son kullanma yazılır; CVV, tutar, düğmeler, form gönderimi yok.
5. 3D Secure/SMS banka sayfaları aynı ekranda açılır. Yalnız `https` gezinmeye
   izin verilir; `http`, `intent:`, `file:`, `javascript:` ve dosya indirme
   engellenir. Kart doldurma ve sonuç okuma **yalnız DenizPay kökeninde** çalışır,
   banka sayfalarına hiçbir betik eklenmez.
6. Sonuç ekranı (Onay/Hata Formu) yüklenince sayfa özeti okunur, Dart'ta çözülür,
   ekranda gösterilir; kişi "Bu cariye kaydet"e basar → doğrudan sunucuya
   (`kaynak: uygulama`, `eslesme: uygulama_ici`). Sunucuda görülene kadar şifreli
   bekleyen kutuda kalır (internet yoksa sonra kendiliğinden). Kimlik kuralı
   (`-h`), çift kayıt ve "farklı tutar" denetimleri bugünküyle aynıdır.
7. "Kapat", ekran kilidi, çıkış ve hesap değişiminde DenizPay çerezleri silinir.

Sınırlar (dürüst): DenizPay'in uygulama içinde açılmayı (WebView) kabul edip
etmediği, 3D Secure sayfalarının orada sorunsuz çalıştığı ve sonuç sayfasının
gerçek HTML'i bilinmiyor; ilk gerçek denemede görülecek. Çalışmazsa güvenli
yedek: "Chrome'da aç" düğmesi + elle sonuç kaydı (otomatik doldurma olmaz).
Gerçek DenizPay'e bizden istek/deneme yapılmaz; testler taklit DenizPay iledir.
PCI uyumluluk iddiası yoktur (web ile aynı).

## 4. Güvenlik ve kurumsal gereksinimler

1. **Kart kasası:** her kullanıcıya Android Keystore'da dışa aktarılamaz
   AES-256-GCM anahtarı (donanım destekliyse donanımda), cihaz kilidi açıkken
   kullanılabilir. Şifreli kayıt uygulamanın özel klasöründe. Ek doğrulama verisi
   web ile aynı alanları bağlar (kullanıcı, cari, kart, son dört, tarih, referans).
   Taslak → tamamla, silme ve "bozuk kaydı sessiz silme" kuralları web ile aynı.
   Buluta yine yalnız maskeli özet gider. CVV/OTP yine yok.
2. **Yedekten/taşımadan dışlama:** Android yedeği ve cihaz aktarımı kapalı
   (`allowBackup=false`, veri çıkarma kuralları). Kart başka telefona geçmez;
   telefon değişirse kart yeniden eklenir (web ile aynı ilke).
3. **Ekran güvenliği:** ekran görüntüsü/kayıt ve "son uygulamalar" önizlemesi
   engellenir (`FLAG_SECURE`).
4. **Ağ:** yalnız HTTPS (açık metin trafiği kapalı), sertifika hatasında sayfa
   açılmaz. WebView'da dosya/içerik erişimi kapalı, sürümde hata ayıklama kapalı.
5. **Oturum:** uygulama her soğuk açılışta ve 5 dk arka plan / 10 dk boşta
   sonrasında kilitli açılır (bugünkü kurallar). Açılış: parmak izi/yüz veya
   hesap şifresi (§6.2). Yetki her istekte sunucuda denetlenir;
   hesap kapatılınca veri ekranı kapanır (bugünkü gibi).
6. **Kod:** R8 küçültme, günlüklere kart/şifre/VKN yazılmaz (test denetler).
7. **Sürüm zorunluluğu:** Firestore'da `ayarlar/android` belgesi (yalnız yönetici
   yazar): en düşük izinli sürüm, son sürüm, indirme adresi, SHA-256. Eski
   sürüm açılınca çalışmaz, "Güncelle" der; kural değişikliklerinde eski
   uygulamanın yanlış kayıt yazması engellenir.
8. **İmza anahtarı:** sürüm anahtarı yerelde üretilir, depoya girmez, 0600 izinli
   proje dışı klasörde + kullanıcının ikinci bir güvenli yerde yedeği. Anahtar
   kaybolursa güncelleme kurulamaz (kaldır-kur = telefondaki kartlar gider).
9. Sunucu kuralları: `posIslemleri` için `kaynak: uygulama` + `eslesme:
   uygulama_ici` eklenir; web kayıtlarının kuralları değişmez (geriye uyumlu).
   Kural testleri genişletilir. Billing kapalı kalır, Cloud Functions yok.
10. Firebase Android API anahtarı (otomatik oluşturuldu) Google Cloud konsolunda
    paket adı + imza SHA-256'sına kısıtlanmalıdır (kullanıcının hesabında yapılır;
    web anahtarındaki açık konuyla aynı). İmza SHA-256:
    `0C:76:96:FC:91:B4:AC:71:91:69:37:A0:50:8E:B5:4C:02:B3:BC:7A:C1:14:C3:53:E8:D3:6F:48:D7:09:47:DB`.
11. Bilinçli sınırlar: köklü (root) telefon ve kötü amaçlı yazılıma karşı
    güvence yok; Play Integrity/App Check Play'siz dağıtımda kullanılmaz;
    Firebase güvenliği yine sunucu kurallarıdır.

## 5. Aşamalar

Her aşama: testler → gözden geçirme → commit + push → kullanıcıya kısa rapor.
Web sürümü her aşamada bütün mevcut testlerinden geçer; web davranışı değişmez.

**Aşama 0 — Hazırlık (davranış değişmez)** — *tamamlandı 27 Ekim (aşağıda "Durum")*
- Paket adı kesinleşir (öneri `com.bup.sanalpos`; kurulduktan sonra değişmez).
- Firebase'e Android uygulaması kaydı (yalnız `bup-sanal-pos-izmir`), istemci
  ayarı `config/` içine, `tools/firebase_ayar.py` iki platformu üretir.
- Bileşimin `bilesim/` altına taşınması, web bağdaştırıcılarının `data/web/`
  altına taşınması; web paketi bayt bayt aynı davranır (bütün web testleri).
- Android lisansları, test emülatörü (AVD), imza anahtarı, `android/` güvenlik
  ayarları, CI'a Android derleme + birim testleri.

**Aşama 1 — Android temel uygulama** — *tamamlandı 27 Ekim ("Durum")*
- Giriş, kilitli açılış, cariler, kart özetleri, yönetim, gün sonu (paylaş ile
  CSV) Android'de; Keystore kart kasası (Kotlin + Dart bağdaştırıcı).
- Testler: Dart birim; Kotlin kasa testleri emülatörde (anahtar dışa aktarılamaz,
  bozulmuş şifreli veri/ek veri reddi, kullanıcı ayrımı, silme, taslak kurtarma);
  Firebase emülatörüne karşı uçtan uca (gerçek kurallar, iki kullanıcı, yetki
  iptali).

**Aşama 2 — Uygulama içi DenizPay** — *tamamlandı 27 Ekim ("Durum")*
- `DenizPayOturumu` portu + WebView bağdaştırıcısı; gezinme politikası; çerez
  ayrımı; "Kartı doldur"; sonuç okuma (Dart) + bekleyen kutu; kural değişikliği.
- Testler: taklit DenizPay (bugünkü test sayfaları: giriş, kart sayfası, Onay/
  Hata formu, tablo/kutu düzenleri, görünmez işaretler) emülatörde; yanlış firma,
  başka kökende doldurma reddi, 3D Secure taklidi, internet kesik iken sonuç,
  aynı numarada başarısız + başarılı, çift kayıt. Yalnız test derlemesinde taklit
  adrese izin verilir; canlı paket bunu içermez (yayın kapısı denetler).

**Aşama 3 — Dağıtım ve güncelleme**
- İmzalı sürüm APK'sı, `ayarlar/android` sürüm denetimi, indirme sayfası,
  resimli kurulum anlatımı (bilinmeyen kaynak izni, ilk açılış), yönetici için
  "kim hangi sürümde" görünümü (kullanıcı profiline sürüm notu).
- Yayın betiği: testler, imza, SHA-256, yayın öncesi kapı (yanlış proje, test
  adresi, hata ayıklama imzası varsa durur).

**Aşama 4 — Gerçek cihaz kabulü (kullanıcıda)**
- Kurulum, giriş, kart ekleme, kilit, DenizPay girişi, kart doldurma, 3D Secure,
  sonuç kaydı, gün sonu, güncelleme. Sonuçlar bu belgeye işlenir. Kabulden önce
  "tamamlandı" denmez.

## 6. Kullanıcı kararları (27 Ekim 2026)

1. **Birkaç çalışan, kişisel telefon; MDM yok.** Uygulama bağlantıdan kurulur.
   Kişisel telefon sonucu: iş profili/uzaktan silme yok; uygulama kaldırılınca
   telefondaki kartlar gider (sunucudaki kayıtlar kalır). Hesap kapatma yönetimde.
2. **Parmak izi/yüz + şifre.** Günlük açılış güçlü biyometriyle (BIOMETRIC_STRONG,
   Android BiometricPrompt, kendi Kotlin kodumuz; anahtar biyometriye bağlı).
   Hesap şifresi istenir: ilk girişte, çıkıştan sonra, telefon yeniden
   başladıktan sonra, 7 gün şifre girilmediyse, biyometri tutmazsa ve **telefona
   yeni parmak izi/yüz eklendiyse** (kişisel telefonda başkasının parmak izi
   eklenebilir; anahtar kendiliğinden geçersizleşir).
3. **Kart doldurma düğmeyle** ("Kartı doldur").
4. **Play Store'suz imzalı APK.** Güncelleme uygulama içinden bildirilir; en
   düşük sürümün altı açılmaz (§4.7).

Kartların webden Android'e taşınması yoktur (bilinçli; kart yalnız eklendiği
cihazda). Android'de kartlar bir kez yeniden eklenir; web kartları yerinde kalır.

## Durum

**Aşama 0 tamamlandı (27 Ekim 2026).**
- Paket adı `com.bup.sanalpos`, en düşük Android 9 (API 28).
- Bileşim `lib/bilesim/`: `PlatformBaglantilari` + `platform.dart` koşullu
  seçimi (web → `platform_web.dart`, diğer → `platform_kapali.dart`). Web
  bağdaştırıcıları `lib/data/web/` altında, adları `Web…`. `AcikGirisPortu`'na
  `yalniz(uid)` eklendi (önceden yalnız web sınıfında, port dışıydı).
  Mimari test: `dart:js_interop`/`package:web` yalnız `data/web/`; `data/web/`
  yalnız `platform_web.dart`, `data/android/` yalnız `platform_android.dart`
  tarafından alınır; çapraz platform içe aktarması yasak (bozuk içe aktarmayla
  denendi, yakaladı).
- `android/`: yalnız HTTPS ve yalnız sistem sertifikaları (`ag_guvenligi.xml`;
  hata ayıklama derlemesinde yalnız 10.0.2.2/127.0.0.1/localhost şifresiz),
  yedek ve cihaz aktarımı kapalı (`allowBackup=false`, `veri_cikarma.xml`),
  sürümde `FLAG_SECURE` (hata ayıklamada test ekran görüntüleri için kapalı),
  R8 küçültme, INTERNET izni ana manifestte.
- Sürüm imzası depo dışı `~/.bup-sanal-pos/imza/` (0700/0600; `BUP_IMZA` ile
  değiştirilebilir). Anahtar yoksa sürüm derlemesi açık mesajla durur; hata
  ayıklama imzasına düşülmez (CI bunu da sınar). RSA 4096, 30 yıl.
- Firebase: `bup-sanal-pos-izmir` projesine Android uygulaması kaydedildi
  (`1:1033835683669:android:bbc86615d73967502899dc`). `tools/firebase_ayar.py`
  `config/canli.json` (değişmedi) ve git dışı `config/android.json` üretir.
- CI: `android` işi (deneme paketi derlemesi + imzasız sürümün reddi).
- Doğrulama: 126 Dart testi; kural testleri; demo/kasa/doldur/hesap/tahsilat
  Chromium + WebKit; `test:saf`; deneme APK ve imzalı sürüm APK derlendi;
  APK içinde imza, paket adı, minSdk ve güvenlik bayrakları `apksigner`/`aapt2`
  ile okundu.
- Açık: imza anahtarının kullanıcı tarafından ikinci güvenli yere yedeklenmesi;
  Android API anahtarı kısıtlaması (§4.10). Android uygulaması henüz yalnız
  deneme kipinde ve platform özellikleri kapalı (Aşama 1).

**Aşama 1 tamamlandı (27 Ekim 2026).**
- Kart kasası: kurallar platformdan bağımsız `lib/data/kasa/sifreli_kasa.dart`
  (web `kart_kasasi.js` ile aynı sözleşme: taslak → tamamla, yarım kalanın
  sunucu referansıyla kurtarılması, ek doğrulama verisi aynı JSON, kayıt varken
  anahtar yoksa yeni anahtar üretmeme, bozuk belgeyi ezmeme, işlemler sırayla).
  Android: `KeystoreSifreleyici` + `DosyaKasaDeposu` (kullanıcı başına tek JSON,
  `noBackupFilesDir/kart-kasasi`, geçici dosya + yeniden adlandırma). Kotlin
  `KasaAnahtari.kt`: kullanıcı başına AES-256-GCM, StrongBox varsa, IV Keystore'da
  rastgele, `setUnlockedDeviceRequired`; ekran kilidi yoksa kart saklanmaz/açılmaz
  ("ekran_kilidi" mesajı). Ödünleşim: tek belge bozulursa o hesabın bütün kartları
  açılmaz (atomik yazma nedeniyle beklenmez; sessiz sıfırlama yerine seçildi).
- Biyometri: `domain/biyometri.dart` (7 gün, açılış sayacı, saat geri),
  `application/biyometrik_kilit.dart` portu, `data/android/biyometrik_kilit.dart`,
  Kotlin `BiyometriAnahtari.kt` (BIOMETRIC_STRONG, anahtar her kullanımda
  biyometri ister, `setInvalidatedByBiometricEnrollment`; başarı CryptoObject ile
  gerçek şifrelemeyle kanıtlanır). Biyometri yalnız ekran kilidini açar; ardından
  hesap yetkisi sunucudan okunur. Kart kasası anahtarı biyometriye bağlı değildir
  (kullanıcı kararı: ek kasa parolası yok).
- Oturum: `PlatformBaglantilari.acilistaKilit` (Android): kalıcı Firebase oturumu
  soğuk açılışta kilitli açılır; şifre doğrulanınca biyometri yenilenir, çıkış ve
  hesap değişiminde silinir (`canli_app.dart`). Kilit ekranı biyometriyi bir kez
  kendiliğinden sorar, vazgeçilirse düğme kalır, şifre her zaman seçenektir.
- Gün sonu: `DosyaIndirici.indir` artık `Future<DosyaSonucu>`; Android "Kaydet"
  penceresi (`ACTION_CREATE_DOCUMENT`), web indirmesi değişmedi.
- Metinler: kart saklama notu Android'de "bu telefonda" (`ui/ortak.dart`
  `androidUygulamasi`); kasa uyarıları platformdan bağımsız sözlerle.
- Firebase emülatör adresi `BUP_EMULATOR_HOST` (Android emülatöründe 10.0.2.2);
  `config/emulator_android.json` yalnız yapay değerler.
- DenizPay girişi/yer imi/sonuç kutusu Android'de kapalı (Aşama 2).

**Doğrulama (Aşama 1):** 151 Dart testi (yeni: `sifreli_kasa_test` 11,
`biyometri_test` 3, `android_baglantilari_test` 8, `giris_biyometri_test` 3);
kural testleri; web demo/kasa/doldur/hesap/tahsilat Chromium + WebKit;
`bash tools/android_test.sh emulator-NNNN` (yalnız emülatör kabul eder):
Kotlin Keystore 4 + kanal kodlama 1, telefon kilitliyken anahtar kullanılamaz,
ekran kilidi yokken kart saklanmaz, uçtan uca (giriş, cari, kart, kasa dosyasında
düz kart yok, kilit, yanlış/doğru şifre, kartın yeniden çözülmesi). Elle emülatör
kabulü (uiautomator ile, gerçek Android biyometri penceresi, sanal parmak izi):
soğuk açılışta kilit; şifreden sonra parmak iziyle açma; soğuk açılışta pencere,
vazgeçip düğmeyle açma; **yeni parmak izi eklenince şifre istenmesi**; şifreden
sonra yeniden etkinleşme; **telefon yeniden başlayınca yalnız şifre**. İmzalı
sürüm APK emülatörde: `FLAG_SECURE` açık, APK'da test kodu yok.
Testlerin bulduğu ve düzeltilen hatalar: (1) kanaldan gelen çözülmüş bayt dizisi
salt okunur, bellekten silme denemesi kart okumayı bozuyordu (sahte şifreleyici
artık salt okunur döner); (2) değer döndürmeyen Kotlin işi (`biyo.sil`) kanalda
`Unit` taşıyamayıp uygulamayı çökertiyordu — tam yeni parmak izi senaryosunda
(`GuvenlikKanali.kanalDegeri` + Kotlin testi); (3) ek doğrulama verisi testi
açık alan denetimi yüzünden boş geçiyordu (kayıttaki açık alanlar özete uyacak
şekilde kurcalanınca da reddi sınayan test eklendi). Hepsi bilerek bozulmuş
kodla testin kırıldığı görülerek doğrulandı.
**Bilinen ve kabul edilen:** `cloud_firestore` Android eklentisi transaction
bittikten sonra "cancel … MissingPluginException" kaydı düşüyor; işlem başarılı,
uygulama etkilenmez; uçtan uca testte yalnız bu tam ileti sayılıp geçilir.
**Ortam notları:** bilgisayardaki emülatör 36.3.10, Android 16.1 (36.1)
görüntüsüyle uyumsuz (SurfaceFlinger `hasReadColorBufferDma` çöküşü); testler
eklenen Android 15 (API 35, Google APIs) görüntüsünde, `-gpu swiftshader_indirect`
ve 4 GB bellekle koşar. Sürüm APK'sı `--no-pub` ile derlenmez (eklenti kayıt
dosyası yenilenmez, test eklentisi sürüme sızmaya çalışır); yayın betiği bunu
zorunlu kılacak (Aşama 3).
**Gerçek telefonda denenmedi:** gerçek parmak izi/yüz, StrongBox, Android 9–14
sürümleri, üretici farkları; kullanıcı kabulü Aşama 4'tedir.

**Aşama 2 tamamlandı (27 Ekim 2026).**
- Kullanıcı isteği (27 Ekim, aşama sırasında): kart kaydı/seçimi olmadan da
  carinin DenizPay hesabına girilebilsin; kart bilgileri o zaman DenizPay'de elle
  yazılır. Web'de zaten böyleydi; Android'de `otomatikGiris` uygulama içi girişle
  açıldığı için aynı kural geçerli (ana ekran "Kart seçmeden de DenizPay’e
  girebilirsin"). Uçtan uca testte kartsız cariyle sınandı.
- Saf kurallar `domain/denizpay.dart`: `DenizPayAdresi` (canlıda yalnız
  `https://denizpay.bupilic.com.tr`; taklit köken yalnız `BUP_EMULATOR` derlemesinde
  ve o zaman aynı makinedeki http taklit banka), `Gezinme` kararı (DenizPay / dış
  https / engel: http, intent, javascript, file, data, kullanıcı bilgili adres),
  `SayfaOzeti`, `sonucCoz` — `web/sonuc_coz.js`'in satır satır karşılığı; ortak
  `test/veri/tahsilat_ornekleri.json`'daki 19 örneğin 17'si birebir aynı sonucu
  verir (2'si yalnız web yer iminin sekme notu biçimidir).
- `application/denizpay_oturumu.dart`: `DenizPayOturumu` (açılışta önceki oturumu
  silip carinin bilgileriyle POST; banka sayfasında betik yok; kart yalnız
  "Kartı doldur"la, firma numarası görünür ve aynıysa, kart sunucuda yeniden
  doğrulanınca; sonuç yalnız "Bu cariye kaydet"le; kapanınca oturum hemen
  silinir), `DenizPayTarayicisi` ve `SonucBirakmaPortu` portları.
  `PosServisi.uygulamaIciGirisHazirla` seçim süresini denetler, giriş kaydını
  hazırlar.
- Kayıt: kaynak `uygulama`, eşleşme `uygulama_ici` (bekleyen sonuç biçimi v3).
  Sonuç Android'in kalıcı kutusuna (`data/android/sonuc_kutusu.dart`, yedeksiz
  klasör, 20 sonuç/30 gün, bozuk dosya `.bozuk` olarak korunur) bırakılır ve web
  ile **aynı** `TahsilatServisi.kutuyuIsle` yolundan yazılır (çift kayıt, farklı
  tutar, internet yokken bekleme, "-h" kimliği aynen). `firestore.rules`
  `kaynak in ['yer_imi','elle','uygulama']`; `uygulama` yalnız `uygulama_ici` ve
  okunma anıyla. Web kayıt kuralları değişmedi. **Kural, Android dağıtımından önce
  yayınlanmalı (Aşama 3).**
- Android: `data/android/denizpay_tarayicisi.dart` (webview_flutter 4.14.1,
  Android eki 4.12.0 — Flutter 3.41 ile uyumlu en yeni): JavaScript açık; dosya/
  içerik erişimi, konum, kamera/mikrofon izinleri, dosya seçme kapalı; karışık
  içerik yasak; SSL hatasında açıkça iptal; sürümde hata ayıklama kapalı. Betik
  (`denizpay_betigi.dart`) web yer imiyle aynı kurallar; betik çalışmadan önce
  açık adres yeniden denetlenir ve betik kökeni kendisi de denetler; kart
  sayfasında ekran yazıları okunmaz. Ekran `ui/denizpay_ekrani.dart` (üstte cari,
  VKN, açık sitenin adresi; kaydedilmemiş sonuç/süren ödemede kapatma onayı).
  Ekran kilidi ve çıkış ekranı kapatır, DenizPay oturumu silinir.
- Yedek yol: onay ekranında "DenizPay’i tarayıcıda aç (yedek)" (sonuç o zaman
  elle kaydedilir).

**Doğrulama (Aşama 2):** 199 Dart testi (yeni: `denizpay_test` 24,
`denizpay_oturumu_test` 10, `denizpay_ekrani_test` 5, `uygulama_ici_gecis_test` 3,
`android_sonuc_kutusu_test` 5, v3 kutu testi, eşleşme/kaynak tutarlılığı); sunucu
kural testleri (Android kaydı: kabul + 9 ret); web tarayıcı takımı değişmeden geçti.
`tools/android_test.sh` uçtan uca, gerçek WebView + taklit DenizPay/banka
(`tools/android_taklit_denizpay.py`): kartlı cari, "Kartı doldur" yalnız numara/ad/
SKT (CVV ve tutar boş), `intent:`/http bağlantıları açılmaz, başka kökende taklit
3D Secure, sonuç okunup kaydedildi, kartsız cariyle giriş ("Kart seçmedin" notu,
düğme yok), başka firmanın kart sayfasında uyarı ve kart yazılmaz, kapatma onayı,
gün sonunda kayıt, taklit sunucu iki girişi de doğru alanlarla aldı.
Testlerin bulduğu ve düzeltilenler: (1) ekran kapanınca oturum önce akışları
kapatmayı bekliyordu, DenizPay çerezleri gecikebilir/silinmeyebilirdi — artık
önce silinir (test eski sırada kırılır); (2) kart sayfasında firma numarası hiç
yoksa "Kartı doldur" açık kalıyordu — web yer imi gibi kapalı (test kuralsız kırılır).
**Bilinmeyen (gerçek denemede görülecek):** DenizPay ve bankanın 3D Secure
sayfalarının WebView'de çalışması, gerçek kart sayfasının alan adları ve sonuç
sayfasının gerçek HTML'i. Okunamayan sonuçta ekran "elle kaydet" der.
