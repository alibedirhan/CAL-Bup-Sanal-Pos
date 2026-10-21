# 21 Ekim 2026 gece — iPhone uçtan uca doğrulandı (kullanıcı)

Ana ekran simgesi yeniden eklendi: iOS "Ana Ekrana Ekle" ekranında "Open as
Web App" anahtarı `display: browser` sayesinde kendiliğinden kapalı geldi;
simge Safari'de açıldı (adres çubuğu var). Kullanıcı: Safari'de giriş →
cari + kart → "DenizPay’e giriş yap" → kart sayfasında BUP Doldur → "kart
yazıldı, çalıştı". Ayrıca standalone uygulamadan açılan uygulama içi tarayıcı
penceresinde otomatik girişin çalıştığı görüldü (doldurma orada yok: yer imi
menüsü yok, depo ayrı). Açık kalanlar: Android denemesi, GitHub (K4), eski
`otomatik-giris` dalı silinebilir (main'e alındı), ödeme/onay gerçek kullanımı.

---

# 21 Ekim 2026 gece — önbellek: no-store → no-cache

Kullanıcı ana ekrandan açınca "sunucudan yanıt çok geç" dedi. Ölçüm: sunucu
hızlı (ilk yanıt ~0,17 sn) ama `Cache-Control: no-store` yüzünden her açılışta
~3 MB sıkıştırılmış dosya (main.dart.js ~0,7 MB + canvaskit.wasm ~2,2 MB)
yeniden iniyordu. Hosting başlığı `no-cache` yapıldı: dosya saklanır, her
açılışta yeniden istenir. Ölçüm: Firebase CDN `no-cache`te ETag'e 304 vermiyor
(her seferinde 200). Bu yüzden ek olarak: `tools/web_hazirla.py` CanvasKit'i
motor sürümlü `canvaskit-<rev12>/` klasörüne taşır ve açılışa
`canvasKitBaseUrl` yazar; `firebase.json` bu klasörü ve `/main.dart.js`'i
(yalnız `?v=<hash>` ile istenir) `max-age=31536000, immutable` saklatır. Küçük
betikler/sayfa `no-cache`. `yayin-kabul.mjs` bunları denetler. Uygulama kodu
değişmedi (0.7.2). Yerel `tools/sunucu.py` no-store kalır.

Kullanıcı ayrıca ana ekrandan açınca DenizPay'in boş giriş sayfasıyla açıldığını
bildirdi (sol üstte "◀ Sanal POS"): simge hâlâ ayrı uygulama olarak açılıyor;
iOS dış bağlantıyı Safari'ye verirken form POST gövdesini taşımaz. iOS'un "Ana
Ekrana Ekle" ekranındaki "Web Uygulaması Olarak Aç" anahtarı kapatılmalı (yeni
iOS'ta manifest'ten bağımsız varsayılan açık olabilir). BUP Doldur giriş
sayfasında doğru şekilde yazmayı reddetti.

---

# 21 Ekim 2026 gece — 0.7.2: ana ekran simgesi Safari içinde açılır

Kullanıcı ana ekrandan açmayı sordu. Anlatıldı: iPhone'da ayrı (standalone)
web uygulamasının deposu Safari'den ayrı; kartlar ve "BUP Doldur" bekleyen
işi orada görünmez; dokunmasız/otomatik doldurma tarayıcıda mümkün değil.
Kullanıcı "1 olsun, Safari içinde açılsın" dedi. `web/manifest.json`
`display: browser`, `index.html`'den `apple-/mobile-web-app-capable` kaldırıldı;
`yayin-kabul.mjs` ikisini denetler. Kullanıcı eski ana ekran simgesini silip
Safari'den yeniden eklemeli (eski simge ayrı depoyu kullanmaya devam eder).
Gerçek cihazda yeni simgenin Safari'de açıldığı henüz doğrulanmadı.
**Yayında** (`2bc9aa4a2a6ac670`); test:yayin canlıda manifest/meta denetimiyle geçti.
Kullanıcı ayrıca ücretsiz iPhone'a USB/dosyayla uygulama kurmayı sordu (bkz. sohbet:
ücretsiz Apple Kimliği 7 günlük imza, Mac/AltStore gerekir; önerilmedi, iş başlatılmadı).

---

# 21 Ekim 2026 gece — 0.7.1: sekme değişimi bekleyen kartı silmez

İlk gerçek iPhone denemesi: yer imi DenizPay kart sayfasında çalıştı, firma
numarasını buldu, `doldur.html`'i açtı (opener var) ama "Bekleyen kart yok"
dedi. Neden: DenizPay sekmesine geçmek Sanal POS'u (görünürlük/lifecycle)
kilitliyor; 0.7.0'da kilit ve model `dispose` işi siliyordu. 0.7.1: yalnız elle
"Ekranı kilitle" ve çıkış/hesap değişimi siler (`canli_app` `_sonUid`); sekme
değişimi, boşta kilidi ve canlı kilidin modeli kaldırması silmez. Süre 10 dk
aynen. 2 yeni Dart testi (73 toplam). Bir önceki kullanıcı adımı: eski "BUP
Deneme" yer imi silindi, "BUP Doldur" yeniden kuruldu ve doğrulandı.

**Yayında** (`b66e940abb80192e`, test:yayin geçti). **Kullanıcının gerçek
iPhone Safari denemesi başarılı:** numara ve SKT yazıldı, kart görseli
güncellendi, doldur sekmesi kendiliğinden kapandı, CVV/tutara dokunulmadı
(tutar kutusunda DenizPay'in kendi ön değeri vardı). Ad Soyad boş kaldı
(kartta "kart üzerindeki ad" girilmemiş). Kullanıcının ekran görüntüsü tam
kart numarası içeriyordu; hiçbir dosyaya alınmadı, silmesi önerildi. Android
henüz denenmedi. Ödeme/onay gerçek kullanımda kullanıcıda.

---

# 21 Ekim 2026 gece — 0.7.0: kart doldurma ("BUP Doldur") ve kartsız giriş

Kullanıcı iPhone Safari'de otomatik girişin çalıştığını bildirdi ve kart
sayfası raporunu gönderdi (`/index.aspx`; `name`, `number`, `expiry`, `cvc`,
`Tutar`, `Button#`; üstte "Firma İsmi : … (VKN)"; card.js görünümlü form).
Ekran görüntüsü gerçek müşteri adı/VKN içerir; dosyaya alınmadı. Kullanıcı
ayrıca kartsız cariyle de DenizPay'e girişi istedi.

Yapılanlar: kartsız giriş (`PosSecimi.kartId` boş olabilir; canlı kipte kart
seçmeden "Ödeme sitesine geç" açık). Aşama 2: `DoldurmaIsi` (domain),
`DoldurmaHazirligi` portu, `web/doldurma.js`, `web/doldur.html` +
`doldur_sayfasi.js`, yer imi `tools/yer_imi/doldur.js`, kurulum
`web/kurulum.html` (Bilgi sayfasında "BUP Doldur yer imini kur"; deneme
bağlantısı ikincil). Ayrıntı MIMARI.md. `uret.py` üç sayfa betiği üretir,
`yayin.sh` canlı kökenleri denetler. Testler: 71 Dart; `test:doldur` (yeni,
Chromium + WebKit: yazma, CVV/tutar/düğmeye dokunmama, firma uyuşmazlığında
yazmama, giriş sayfası/başka site, kötü açan, süre); `test:hesap` emülatörde
işin kurulduğunu (kartsız) ve kilitte silindiğini doğrular. Gerçek DenizPay'de
doldurma kullanıcıca denenmedi; card.js'in değeri kabul edip etmediği orada
görülecek. Kullanıcı telefonda yer imini "BUP Doldur" olarak yeniden kurmalı.
**Yayında:** kullanıcı izniyle Claude yayınladı, kod özeti `cdbbc57440eb7d4e`, test:yayin geçti.

---

# 21 Ekim 2026 akşam — 0.6.0: DenizPay'e otomatik giriş

Kullanıcı açıkça "kaydettiğim cari ile giriş yapılmalı… otomatik girişi yap"
dedi ve Claude Code otomatik izin kipini kapattı. `otomatik-giris` dalındaki
taslak main'e alındı ve tamamlandı: seçim kontrolünden sonra "DenizPay’e giriş
yap" düğmesi (2 dk içinde, kilitliyken değil) `web/pos_giris.js` ile
`login.aspx`'e form POST'u yapar (`__VIEWSTATE` boş, `lvergino`,
`lkullaniciadi` = VKN/TC, `lsifre` = ilk 2 + son 2, `btngiris`); yeni sekme
`noopener`, geçici form gezinmeden sonra silinir (CAL bup gibi). "Boş giriş
sayfasını aç" yedek. CSP `form-action` `'none'` → yalnız
`https://denizpay.bupilic.com.tr` (firebase.json, tools/sunucu.py);
`yayin-kabul.mjs` bunu birebir denetler. Testler: 3 yeni Dart (düğmesiz
gönderim yok, doğru değerler, süre/kilit reddi); `hesap-kabul.mjs` gerçek form
POST'unu Playwright'ta yakalayıp yapay sayfayla yanıtlar — gerçek DenizPay'e
istek yok; alanlar, POST, sorgusuz URL, `opener` yok, kart bilgisi yok.
Giriş sonucunun gerçek DenizPay'de çalıştığı doğrulanmadı (ilk deneme
kullanıcıda). **Yayında:** kullanıcı yayin.sh çalıştırdı, kod özeti `cbd123b7e5d40b24`, test:yayin (CSP form-action birebir) geçti. Kullanıcının ilk iPhone denemesi: bkz. MOBIL_DOLDURMA_PLANI durum
satırı. **Kullanıcı iPhone Safari gerçek denemesi: "giriş yapılmış olarak açıldı" — otomatik giriş çalışıyor.** Kart sayfası raporu bekleniyor.

---

# 21 Ekim 2026 — telefonda giriş/kart doldurma planı (uygulanmadı)

Kullanıcı kart seçip ödeme sitesine geçince bilgilerin kendiliğinden dolmasını,
yalnız tutar yazmayı ve fotoğraftan kart okumayı istedi. Yerel uygulama, Apple
ücreti ve Google Play istemedi; DenizPay'den bilgi alınamadı. Plan:
[MOBIL_DOLDURMA_PLANI.md](MOBIL_DOLDURMA_PLANI.md) — giriş için CAL bup'taki
form POST yöntemi, kart sayfası için köken denetimli yer imi betiği, önce
bilgi doldurmayan deneme yer imi. Kod/yayın/gerçek POS denemesi yapılmadı.
Bekleyen kararlar: CVV (K1), iPhone'da Safari kullanımı (K3), depo henüz hiç
commit içermiyor — ilk commit/uzak depo (K4).

**Aynı gün sonrası:** Kullanıcı: CVV şimdilik doldurulmaz; git yalnız yerel,
GitHub sonra. İlk commit `8281b48`. **0.5.0** (`3fe35f5`, main): Aşama 0
deneme yer imi `tools/yer_imi/deneme.js` + `web/deneme.html`/`deneme.js`,
Bilgi sayfasında bağlantı, yayında test kökeni kalmama kontrolü
(`tools/yayin.sh`). 59 Dart, demo/kasa/yer imi tarayıcı testleri (Chromium +
WebKit) başarılı. **Yayımlanmadı:** Claude Code izin denetimi canlı yayını
engelledi; kullanıcı onayı/izni bekleniyor. Aşama 1 otomatik giriş taslağı
yalnız `otomatik-giris` dalında (yarım: ekran bağlantısı ve CSP `form-action`
yok). İzin denetimi giriş bilgisini DenizPay'e gönderme ve CSP açma adımlarını
"güvenlik zayıflatma" diye durdurdu; karar kullanıcıda.

**0.5.1 (aynı gün):** Kullanıcı "tüm gerekli işleri bitir" dedi. Otomatik
giriş taslağını main'e alma adımı izin denetimince yine durduruldu
("Security Weaken"); dolanılmadı. Aşama 3'ün ilk adımı yapıldı: kart
formunda `AutofillGroup` + `cc-number/cc-name/cc-exp-month/cc-exp-year`
ipuçları; yeni kartta numara açık başlar (gizli/parola kutusunda telefonun
kart tarama/önerisi çıkmaz), kayıtlı kart gizli açılır. Not: Flutter web
erişilebilirlik (semantics) kipinde `autocomplete=off` yazar; bu yüzden ipucu
`test/kart_formu_test.dart` ile, açık yazı kutusu `hesap-kabul.mjs` ile
sınanır. iPhone "Kartı Tara" gerçek cihazda doğrulanmadı. 60 Dart; demo,
hesap (emülatör), kasa, yer imi tarayıcı testleri Chromium + WebKit geçti.
Aşama 2 kart doldurma: DenizPay kart sayfasının alan adları bilinmiyor
(CAL bup eklentisi de sabit ad değil kullanıcı tanıtması kullanıyor); telefon
deneme raporu gelmeden yazılmaz.
**Yayın:** Kullanıcı `bash tools/yayin.sh`'yi kendisi çalıştırdı; 0.5.1
canlıda (kod özeti `c7314b40c33760a0`). `test:yayin` Chromium + WebKit geçti;
canlı `deneme.js` gerçek DenizPay kökenini taşıyor. Sıradaki: kullanıcının
iPhone Safari + Android Chrome deneme raporu, otomatik giriş izni/kararı, K3.

---

# 19 Ekim 2026 — 0.4.1: doğrudan DenizPay giriş bağlantısı

Kullanıcı ana sayfa yerine `https://denizpay.bupilic.com.tr/login.aspx`
adresinin açılmasını istedi. Doğrulanan cari/kart seçiminden sonra bu sabit
HTTPS adresini ayrı tıklamayla yeni sekmede açan bağlantı yayımlandı.
URL'ye kimlik, şifre veya kart bilgisi eklenmez. Bilgi sayfası ve sürüm
etiketi güncel. Önceki ana sayfa tercihi artık tarihsel karardır.

Kullanıcının otomatik giriş + kart + CVV aktarımıyla yalnız tutar girme
isteği henüz karşılanmadı. Web uygulaması dış Safari/Chrome sayfasındaki
alanları dolduramaz; bunun için sağlayıcı işbirliği gerekir. Resmi
DenizPay API/token/hosted desteği doğrulanmış değil. Teknik yetkili veya
belge bağlantısı kullanıcıya soruldu; bu kayıt sırasında yanıt gelmedi.
POS_KARARI.md'de gereken sağlayıcı bilgileri ve sonraki yol kayıtlı.
Yerel Android/iOS dağıtımı seçilmedi; WebView uyumu varsayılmaz.

CVV alanı/saklaması eklenmedi. PCI SSC FAQ 1280, belirli işlem öncesi
alınmasıyla sonraki ödemeler için saklanmasını ayırır; yetkilendirme sonrası
şifreli saklama ve müşteri onayı istisna değildir. CVV şimdilik ödeme
sitesinde işlem anında girilir. Gerçek POS'a hiçbir istek, giriş,
kart/ödeme/SMS denemesi yapılmadı; kullanıcı kayıtlarına dokunulmadı.

**0.4.1+6 yayında:** https://bup-sanal-pos-izmir.web.app/ .
Canlı kod özeti `450074ba4fad6012`. Biçim/statik analiz, **57 Flutter/Dart
testi**, **4 demo tarayıcı** ve **2 canlı HTTPS giriş kontrolü** başarılı.
Yeni testler canlı ekranı yalnız sentetik bellek deposuyla açar: onay öncesi
bağlantı yok; doğrulanan seçimde tam hedef/HTTPS/yeni sekme ve boş query,
fragment, userInfo; sunucuda silinmiş seçimde bağlantı yok. Gerçek ödeme
adresine test isteği atılmaz. Yayın dosyası yerel derlemeyle birebir eşleşti;
HTTPS başlıkları ve oturumsuz Firestore okuma reddi yeniden doğrulandı.

Bu tur yalnız Hosting yayımlandı; sunucu kuralları/veri modeli/kart kasası
kodunda değişiklik yok. Önceki 0.4.0'ın kural/kasa/SDK testleri bu tur tekrar
çalıştırılmadı. Yayın öncesi ayrı proje, Auth etkin, min6 ve billing kapalı
kapısı geçti. Günlükler `/tmp/bup-pos-041-*.log`. Yerel demo 4195 açık;
emülatör açılmadı. Fiziksel iPhone kabulü kullanıcıdadır. CAL bup ve Sipariş
kaynakları değiştirilmedi; CAL'daki eski tasarim-ornekleri dosyaları korundu.

---

# 18 Ekim 2026 — 0.4.0: her cariye cihazda şifreli tam kart

Kullanıcı CAL bup gibi her cariye birden çok tam kart eklenmesini istedi.
Mevcut CAL kaynakları salt okunur incelendi; gerçek şirket/kart verisi
alınmadı. CAL bup sayfası web aracıyla açılmadı; kaynak kodu karşılaştırıldı.
Kullanıcı ayrı kasa parolasını istemedi; sorulduğunda tam kartın şimdilik
**yalnız eklendiği cihazda kalmasını** seçti. Bu karar önceki PAN formu
kısıtının yalnız cihazda saklama için açık istisnasıdır. CVV/OTP toplanmaz.

Kart ekle formu cari adıyla bağını açık gösterir; kart adı, tam numara,
kart üzerindeki ad, ay/yıl ve isteğe bağlı Türkiye cep telefonu alır.
Numara biçim/Luhn denetlenir, varsayılan maskelidir; açık “göster” eylemi var.
Kayıtlı kartlar sayılı, ekle düğmesi üstte; her kartta Bilgiler/düzenle ve
onaylı silme var. En fazla 10 kart. Tam kartı panoya kopyalama veya otomatik
POS form doldurma eklenmedi. Kullanıcı gerçek ödemeyi resmi sitede yapar.

Yerel Web Crypto AES-GCM 256/CryptoKey nonextractable ve IndexedDB kasası.
Tam numara/kart üzerindeki ad/telefon ağ modeline girmez; Firebase yalnız
eski maskeli özet + opak cihazKayitId saklar. Ayrı parola/ücretli hizmet yok.
Yerel anahtar aynı tarayıcı profilindedir; donanım güvenliği veya PCI
uyumluluk iddiası yoktur. Tarayıcı verisi silinirse veya farklı tarayıcı/PWA
saklama alanına geçilirse tam bilgi kaybolur; diğer cihazlar yalnız özeti
alır. Kullanıcı bu kısıtı cevapta kabul etti. Ayrıntı CIHAZ_KART_KASASI.md.

Önce şifreli taslak, sonra sürüm kontrollü sunucu özeti, sonra yerel
etkinleştirme yapılır. Reddedilen yazma eski yerel bilgiyi ezmez. Belirsiz
sonuçta taslak korunur; güncel sunucu referansına dayanarak kurtarılır.
Son yerel adım hatası sunucu başarısını yanlış hataya çevirmez; uyarı verir.
Yerel okuma önce güncel sahip/kart referansını doğrular; kilit/eski kayıt
ve yetki değişikliği açık veriyi engeller. Form erişim değişiminde hassas
kontrolleri temizler. Yerel veri okunamazsa sessiz reset/düz metin yedeği yok.

Sunucu yalnız opak referans ek alanını kabul eder; numara/sahip/telefon/CVV
alanlarını ve etiket kutusuna uzun numara yazmayı reddeder. Yeni/değişen
kartta referans zorunlu; eski istemcinin yeni kart referansını düşürerek
yerel bilgiyi erişilemez yapması önlendi. Eski kart özetleri okunur ve
cari adı vb. güncellemelerde korunur; gerçek veri göçü yapılmadı.

**0.4.0+5 yayında:** https://bup-sanal-pos-izmir.web.app/ .
Kod özeti `a534714dd1ab6182`. Biçim/statik analiz, **55 Flutter/Dart testi**,
**19 sunucu kural testi**, **4 demo tarayıcı**, **2 gerçek Web Crypto/IDB**,
**2 SDK/emülatör hesap turu** ve **2 canlı HTTPS giriş turu** geçti.
Hesap turunda iki kart, aynı tarayıcıda yeniden açma+düzenleme, ayrı tarayıcı
profilinde yalnız özet, atama ve yetki iptali doğrulandı; hassas alanların ağ
isteğine girmediği denetlendi. Gerçek veri/kartla test yapılmadı.
Yayın bildirimi sonrası kısa CDN yayılımında eski düz main.dart.js geldi;
yayın kontrolü bootstrap ile aynı sürümlü adresi ve sınırlı hazır olma
tekrarını kullanıyor. Son gerçek HTTP kod eşleşmesi ve görsel kontrol geçti.
Yerel demo 4195 açık; 4197 ve emülatör test hizmetleri kapatıldı.
Günlükler /tmp/bup-pos-040-*.log. Gerçek kart/ödeme denemesi yok; fiziksel
iPhone kabulü kullanıcıdadır. Emülatör demo-bup-pos 8088/9098, önizleme 4197.

---

# 18 Ekim 2026 — 0.3.0: VKN/TC ile cari ve kayıt sonrası hata düzeltmesi

Kullanıcı iPhone/Safari'de yeni cari kaydında “Kayıt okunamadı. Yöneticiyle
görüşün.” hatası gördü. Yenileme/giriş sonrası carinin göründüğünü doğruladı.
Gerçek kayda yazılmadı/silinmedi; mevcut şemanın alan türleri salt okunur
kontrol edildi, değerler günlüğe/kaynağa/teste taşınmadı.

Cari kodu bütün kullanıcı formları/listeleri/profilden kaldırıldı. Cari adı
ve 10/11 rakam VKN/TC istenir; arama ad veya VKN/TC ile çalışır. Eski kod
metadata ve rezervasyon alanı geriye uyumluluk için korunur; yeni kayıtta
VKN/TC'den gelir. Mevcut kaydın kimliği aynıysa eski kodu korunur; gerçek
kayıtlar göç ettirilmedi. Mevcut cari tekrar oluşturulmadan kullanılabilir.

POS giriş şifresini kullanıcı ilk iki + son iki hane olarak bildirdi. Bu
kural ödeme sunucusunda denenmedi. Açık “POS şifresini kopyala” düğmesinde
hesaplanır; normalde gösterilmez ve saklanmaz. Uygulama hesap şifresinin
minimum 6 karakter kuralından ayrıdır. Otomatik giriş/kart doldurma yapılmaz.

Onaylanmış cari/kart yazmasından sonraki fazladan liste+profil okumaları
kaldırıldı: ekran onaylanmış sonuçla güncellenir, sunucu akışı sürer. Okuma
gecikmesi kaydedilmiş cariyi başarısız göstermez. Zaman aşımı artık bağlantı
ve olası yazma belirsizliği olarak anlatılır. İşlem sırasındaki geçici
bağlantı metadata olayı sonucu iptal etmez; yetki iptali/kilit hâlâ geç yanıtı
reddeder. Kesin fiziksel Safari istisna türü yakalanmadı; kayıt sonrası
okuma gecikmesi koşulu testle tekrarlandı. Fiziksel cihaz kabulü kullanıcıda.

**0.3.0+4 yayında:** https://bup-sanal-pos-izmir.web.app/ .
Kod özeti `9354db432612c835`. Üst sürüm etiketi de 0.3.0 olarak düzeltildi. Biçim/statik analiz, **50 Flutter/Dart testi**,
**4 demo tarayıcı turu**, **2 gerçek SDK/emülatör hesap turu** ve
**2 canlı HTTPS salt okunur giriş kontrolü** geçti. Sunucu kuralları değişmedi.
Hesap testinde CSP ile izin verilen Google Auth helper kaynağı apis.google.com
ayrıca ağ izin listesine eklendi; diğer harici ağ hâlâ engellidir.
Yerel demo 4195 açık; 4197/emülatör test hizmetleri kapatıldı.
Kontroller `/tmp/bup-pos-030-*.log`; yeni regresyonlar, eski kayıt uyumluluğu,
5/6 karakter şifre sınırı, POS şifresi/baştaki sıfır ve açık pano isteği,
bağlantı metadata olayı/yetki iptali kapsanır. Gerçek POS'a istek yapılmadı.

---

# 18 Ekim 2026 — 0.2.1: minimum şifre 6 karakter

Kullanıcı minimum 12 karakter yerine **6 karakter** istedi. Güncel politika
6–128 karakterdir; aşağıdaki 0.2.0 kaydındaki 12 karakter sınırı tarihsel
kayıttır ve artık uygulanmaz. Yalnız yeni bup-sanal-pos-izmir projesinin
Firebase Auth sunucu politikası güncellendi ve API yanıtıyla doğrulandı.
Hesap açma, şifre değiştirme, hata/yardım metinleri, kurulum aracı ve yayın
öncesi kapı aynı sınıra getirildi. Üst sınır 128; ilave harf/rakam/özel
karakter şartı eklenmedi. Mevcut şifreler değiştirilmedi.

Şifre değişiminde beş karakterin sunucu portuna gitmeden reddedildiği,
altı karakterin kabul edilip başarı akışını tamamladığı widget testi eklendi.
Sürüm **0.2.1+3 yayında**: https://bup-sanal-pos-izmir.web.app/ .
Biçim/statik analiz, 42 Flutter/Dart testi, 4 demo tarayıcı kabulü ve
2 canlı HTTPS Chromium/WebKit kontrolü geçti. Yayın kod özeti
`68c80af38333e359`. Günlükler `/tmp/bup-pos-021-{auth,kontrol,tarayici,yayin,yayin-kabul}.log`.
Sunucu kuralı değişmedi; kural testlerini yeniden çalıştırmak gerekmedi.
Gerçek kullanıcı şifresi alınmadı, gerçek POS'a istek yapılmadı.

---

# 18 Ekim 2026 — 0.2.0: giriş, kalıcı kayıt ve bağımsız yayın

## Kullanıcı kararları ve tamamlanan altyapı

Ayrı Flutter Web projesi; Android/iPhone bağlantıdan ve ana ekrandan açılır.
Herkes yalnız kendisine atanmış carileri görür; CAL bup kayıtlarından
bağımsızdır. Kullanıcı bütün gerekli uygulamayı yetkilendirdi. E-posta/şifre,
hesapları yöneticinin açması seçildi. İlk yönetici e-postası kullanıcıdan
alındı; gerçek adresi kaynak/test/belgelere yazmayın.

Kullanıcı Firebase Authentication ilk kurulumunu tamamladı. E-posta/şifre
etkin; parola politikası ENFORCE 12–128 karakter, hesap gizliliği etkin,
anonim/telefon girişi kapalı. İlk yönetici Auth kimliği ve aktif yönetici
profili açıldı. Rastgele başlangıç şifresi gösterilmedi; kullanıcının kendi
şifresini seçmesi için bağlantı proje dışında
`/home/ali/.local/share/bup-sanal-pos/ilk-giris.html` dosyasında (0600, üst
dizin 0700). Dosyayı/tokeni okumayın, günlüğe veya kaynağa taşımayın. E-posta
gönderilmedi. İlk girişte kullanıcı sitedeki “Şifremi unuttum” düğmesiyle de
kendi e-posta adresine yeni bağlantı isteyebilir. Bootstrap aracı mevcut
ilk yöneticiyi yeniden açmaz veya rol yükseltmez.

Yeni Firebase projesi yalnız `bup-sanal-pos-izmir`, Firestore europe-west3,
web uygulaması oluşturuldu. Billing API ile kapalı doğrulandı; ücretli plan
veya Functions açılmadı. Firestore kuralları/indeksleri sunucuya yüklendi.
**Hosting yayını tamamlandı:** `https://bup-sanal-pos-izmir.web.app/`.
Canlı sürüm 0.2.0+2, ana kod SHA-256 özeti `30cfaf43e5cb5920`. Eski CAL bup, Sipariş ve
masaüstü kaynaklarına/verilerine yazılmadı.

## Çalışan uygulama kapsamı

Canlı Firebase Auth/Firestore bağdaştırıcıları; aktif profil sunucu kontrolü;
yalnız atanmış cari listesi; kalıcı cari CRUD, isteğe bağlı VKN/TC biçimi;
yalnız etiket/son dört hane/tarih içeren kart özeti CRUD. Tam kart, CVV,
OTP veya DenizPay şifresi toplanmaz/saklanmaz.

Yönetici kullanıcı açabilir, normal hesap erişimini kapatıp açabilir,
carileri aktif kullanıcılara atayabilir. İkincil Auth yönetici oturumunu
bozmaz. Veri kuralları sahiplik/aktif profil/alan şeması/sürüm artışı,
atomik kod rezervasyonu ve değiştirilemeyen minimal denetim kaydı zorlar.
Kart doğrulaması yeni/değişen tek öğeyi küme farkıyla denetler; on kart
pozitif ve on birinci kart negatif kural testi var. Silme yumuşaktır;
kartlar temizlenir, kod bırakılır, metadata/denetim sunucuda kalır.

SESSION oturumu, kapalı Firestore disk önbelleği, açık sunucu okumaları;
arka plan/10 dakika boşta kilit ve tekrar parola doğrulaması. Profil erişimi
iptal edildiğinde çalışma alanı kapanır. FlutterFire SDK sürümü kilitli
paketten okunur; dış modülle gstatic üzerinden yüklenir, script unsafe-inline
gerekmez. Auth yardımcı iframe’i için Google apis.google.com betik kaynağı
CSP’ye eklendi; gerçek HTTPS WebKit kontrolünde gerekliliği görüldü. Roboto
ve CanvasKit yereldir. Demo ile canlı paketleri ayrıdır.

Kullanıcının son tercihi Bupiliç ana sitesi → Online İşlemler → Online Ödeme,
telefonun kendi tarayıcısıdır. Ana sayfa salt okunur incelendi; gerçek POS'a
istek/gitme/giriş/ödeme denemesi yapılmadı. Uygulama ana siteyi ayrı kullanıcı
tıklamasıyla açar, URL'ye veri koymaz. **Seçili kartın otomatik doldurulması
bitmedi.** Resmî sağlayıcı entegrasyonu/sandbox veya ayrıca kararlaştırılmış
native çözüm gerekir. Web uygulamasının başka sitenin alanlarını doldurduğu
iddia edilmez. Ayrıntı `POS_KARARI.md`.

## Doğrulama ve araçlar

0.2.0 biçim/statik analiz ve **41 Flutter/Dart testi geçti**. Firebase
emülatöründe **17 sunucu kural testi** geçti. Gerçek SDK ile yerel Auth ve
Firestore'a bağlanan **2 tarayıcı hesabı turu** Chromium/WebKit geçti:
giriş, kayıtların yenilemede korunması, kilit/yeniden doğrulama, yönetici
hesap açma, atama, yeni kullanıcının atanmış kaydı görmesi, yetki iptali.
WebKit iptal edilen yerel streaming RPC'yi CORS benzeri pageerror olarak
raporlayabiliyor. Test yalnız bağımsız requestfailed=Load request cancelled
ile aynı RPC oturumuna ait hatayı ayırır; diğer hatalar testi düşürür.
Bu ayrım ve SDK başlangıç sırası CANLI_ALTYAPI'de açıklanmıştır.

**4 demo tarayıcı kabulü** (Chromium 320/390/1280, WebKit 390) geçti;
harici ağ engelli, eksik yerel dosya veya sayfa hatası yok.
Flutter'ın farklı çıktı dizinleri arasında artımlı derlemede önceki
paketin statik dosyalarını silmesi giderildi: bütün derlemeler önce
`build/derleme`, sonra bağımsız kopya olarak web/emulator/canli'ye çıkar.

Kontroller: `tools/kontrol.sh`, `tools/sunucu-test` npm test,
`tools/tarayici/kabul.mjs`, `hesap-kabul.mjs`; yayın öncesi kapı ve
`tools/yayin.sh` yalnız doğru canlı projeyi kabul eder. `yayin-kabul.mjs`
yeni HTTPS giriş ekranını/veri erişim reddini ve yayın kod hash'ini kontrol
eder; giriş, ödeme veya yazma yapmaz. **İki canlı HTTPS kontrolü de geçti:**
Chromium ve WebKit 390×844; giriş alanları, hatasız başlangıç, ağ/kod
eşleşmesi, CSP başlıkları ve oturumsuz iki koleksiyonda 403 PERMISSION_DENIED.
Canlı veritabanında bir aktif yönetici ve sıfır cari doğrulandı. Özel kullanıcı
şifresiyle canlı giriş yapılmadı; kullanıcı şifresini kendisi belirleyecek.
Gerçek cihaz/VoiceOver/TalkBack,
ana ekran kurulumu, yavaş fiziksel cihaz ölçümü, sağlayıcı entegrasyonu ve
işletme yedek/geri yükleme süreci hâlâ kabul bekler. Testler yalnız yapaydır.

Günlükler `/tmp/bup-pos-{kontrol-02,kurallar,hesap-kabul,tarayici,yayin}.log`;
görseller `/tmp/bup-pos-qa/`, `/tmp/bup-pos-qa-02/`. Eski `*-hata.png`
dosyaları güncel sonuç değildir. npm üretim bağımlılığı taraması sıfır
bilinen açıklık döndü. Son canlı kontrol günlüğü `/tmp/bup-pos-yayin-kabul.log`; canlı görseller
`/tmp/bup-pos-qa-02/*-canli-giris.png`. Yerel demo 4195’te açık bırakıldı;
emülatör/4197 test hizmetleri kontrol sonrası kapatıldı.
Kaynak deposu kendi main dalında, henüz commit/uzak
depo yok. Gerçek Firebase ayarı config/canli.json git dışı; Firebase CLI
oturumu ve özel reset dosyası yayına/depo içine alınmaz.

---

# 18 Ekim 2026 — bağımsız Flutter projesi, 0.1.0

Kullanıcı ayrı proje oluşturulmasını onayladı. Seçimleri: Sipariş gibi linkten
açılan/ana ekrana eklenen ilk sürüm; herkes yalnız kendisine atanmış carileri
görür; CAL bup ile kayıt ilişkisi şimdilik yoktur. Proje `Bup-Sanal-POS/`.

## Hazır olan

- Flutter Web, yerel yazı tipleri, uygulama simgeleri ve web manifesti.
- Telefon odaklı cari listesi, Türkçe arama, yıldızlı/kartlı filtreleri;
  cari oluşturma/düzenleme/silme ve tekrar kullanılan kod denetimi.
- Maskeli yapay kartlar, süresi dolmuş kartın engellenmesi, açık seçim/onay,
  gerçek ödeme yapmayan geçiş denemesi.
- Arka planda veya 10 dakika hareketsizlikte ekran gizleme/kilitleme;
  seçimlerin ve açık pencerelerin bırakılması, geç yanıtın gösterilmemesi.
- Saf iş kuralları, servis portları, bellek deposu ve UI ayrımı.
- Sentetik birim/arayüz/mimari testleri ve yalnız yerel ağ kullanan tarayıcı
  kabulü. Kontrol komutları README'de.

## Sınır ve sonraki iş

Bu sürüm bir önizlemedir. Demo kullanıcısı sabittir, gerçek hesap girişi
yoktur. Kayıtlar yalnız bellektedir ve yenilemede sıfırlanır. Cari atama kuralı
sentetik depo/servis testleriyle modellenmiştir; sunucuda uygulanmış değildir.
Ekran kilidi gerçek kimlik doğrulama veya belleği şifreleme değildir.
Tam kart numarası/CVV/OTP alınmaz. Gerçek POS, ödeme veya SMS yapılmadı.

Sonraki çalışma: önce sağlayıcının belgelenmiş mobil web/API/hosted akışı
netleştirilecek; ardından bağımsız hesap/veri alanı, sunucu yetkilendirmesi,
kalıcı depo ve uygun sağlayıcı adaptörü kurulacak. CAL bup'ın masaüstü MV3
yardımcısı telefonda çalışır varsayılmayacak. Ayrıntı `MIMARI.md`.

HTTPS yayını yapılmadı. Yerel önizleme `http://127.0.0.1:4195` yalnız bu
bilgisayardan açılır. Gerçek Android/iPhone, ana ekrana ekleme, TalkBack/
VoiceOver ve yavaş cihaz kabulü sonraki aşamadadır. Android/iOS klasörleri
yalnız Flutter iskeletidir; yerel paketler derlenmedi.

CAL bup, Sipariş ve masaüstü kodu değiştirilmedi; gerçek şirket kayıtları veya
yapılandırma taşınmadı. Başka projelerin kullanıcı ilerlemeleri korundu.

## Doğrulama

Biçim ve statik analiz başarılı; **35 Dart/Flutter testi başarılı**.
Web release derlemesi başarılı; giriş paketi hash'i `d9aa74907f7e50c8`.
**4 tarayıcı kabul turu başarılı:** Chromium 390×844, 320×740 ve 1280×900;
WebKit 390×844. Her tur arama/boş sonuç, cari oluşturma/aynı kod reddi,
kart seçimi/zorunlu onay, ekran kilidi sonrası seçimin bırakılması ve
yenilemede kayıtların sıfırlanmasını doğruladı. Harici istek, eksik yerel
varlık veya tarayıcı hatası yoktu. Bu, fiziksel telefon kabulü değildir.

Widget testleri 320/390/1024 genişlik ve 1/1,5 yazı ölçeğini, arka plana
geçişte açık onay penceresinin kapanmasını ve hareketsizlik kilidini kapsar.
Depo/servis testleri başka kullanıcı erişimi, eski/silinmiş kayıt, süresi
dolmuş kart, çift işlem ve kilit sonrası geç yanıt sınırlarını kapsar.
Canlı kipin otomatik demo açmaması ayrıca doğrulanır.

Yazı tipleri yerel Roboto ailesi olarak paketlendi; Flutter motorunun
varsayılan harici Roboto isteği kaldırıldı. Klavye olaylarını izleyen Focus
düğümü odak hedefinden çıkarıldı; ilk açılışta boyutlandırılmamış öğe üzerinde
odak sıralaması hatası giderildi. Tarayıcı yazma yardımcısı motorun odak
karesini bekler; erişilebilirlik duyurusu ve asıl hata metni ayrı sayılır.

Günlükler `/tmp/bup-pos-kontrol.log`, `/tmp/bup-pos-tarayici.log`; son
başarılı görseller `/tmp/bup-pos-qa/` altındadır. Önceki başarısız testlerden
kalan `*-hata.png` dosyaları güncel sonucu temsil etmez.
Proje kendi `main` Git deposuyla başlatıldı; commit/uzak depo/yayın yapılmadı.
Önizleme sunucusu açık bırakıldı. Gerçek sağlayıcıya istek gönderilmedi.
