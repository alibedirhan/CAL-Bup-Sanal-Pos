# Telefonda giriş ve kart doldurma planı — 21 Ekim 2026

Durum (21 Ekim akşam): Aşama T, 0 ve 1 uygulandı (0.6.0); Aşama 3'ün ilk
adımı (kart formu `cc-*` ipuçları) 0.5.1'de. Aşama 2 bekliyor. iPhone Safari
ilk deneme sonucu: yer imi DenizPay'de çalışıyor (CSP engellemiyor); giriş
sayfası alanları `lvergino`, `lkullaniciadi`, `lsifre`, `btngiris` (CAL bup ile
aynı); B kanalında açılan Sanal POS sayfası `opener`'ı gördü ve yanıt gönderdi,
DenizPay tarafında alındığı doğrulanamadı; A kanalında `opener` yoktu. Kart
sayfası alan raporu henüz yok.

## Kullanıcı isteği ve sınırlar

Kullanıcı Sanal POS'ta cari ve kart seçip ödeme sitesine geçtiğinde giriş ve
kart bilgilerinin kendiliğinden dolmasını, yalnız tutarı yazmayı istiyor.
Kartın fotoğraftan okunması da isteniyor. Android ve iPhone'da çalışmalı.

Kullanıcı kararları (21 Ekim): yerel Android/iOS uygulaması yazılmaz, Apple
geliştirici ücreti ödenmez, Google Play'e uygulama gönderilmez. DenizPay'den
teknik bilgi/API alınamadı. Bu nedenle [POS_KARARI.md](POS_KARARI.md)'deki
"resmi entegrasyon veya yerel WebView" yolu şimdilik kapanmıştır.

Değişmeyen kurallar: gerçek DenizPay'e bizden istek, giriş, kart, ödeme veya
SMS denemesi yapılmaz. Bütün testler yapay taklit POS ile yapılır. İlk gerçek
deneme kullanıcıdadır. Tutar asla doldurulmaz. Ödeme/onay düğmesine asla
basılmaz. CVV şimdilik saklanmaz (bkz. Karar K1).

## Teknik sınır

Tarayıcının aynı köken kuralı, `bup-sanal-pos-izmir.web.app` kökeninin
`denizpay.bupilic.com.tr` sayfasındaki alanlara yazmasını engeller. Bunu aşan
iki standart ve ücretsiz araç kullanılır:

1. **Çapraz site form gönderimi (giriş için).** CAL bup `platform/posGiris.ts`
   zaten sabit `login.aspx` adresine geçici HTML formuyla POST yapıyor
   (`lvergino`, `lkullaniciadi`, `lsifre`, `btngiris`, boş `__VIEWSTATE`).
   Kullanıcı bunun CAL bup'ta çalıştığını bildirdi. Bu yöntem yer imi
   gerektirmez; her tarayıcıda ve ana ekran uygulamasında çalışması beklenir.
2. **Yer imi betiği (kart sayfası için).** Kullanıcının bir kez eklediği
   `javascript:` yer imi, dokunulduğunda DenizPay sayfasının kendi kökeninde
   çalışır ve alanlara yazabilir. Kart bilgisi yer iminde durmaz; sayfalar
   arası `postMessage` ile, yalnız tam köken eşleşmesinde Sanal POS'tan alınır.

Bu yolun bilinmeyenleri (yalnız gerçek cihazda, kullanıcı denemesiyle
öğrenilebilir):

- DenizPay sayfası yer imi betiğini (CSP ile) engelliyor mu?
- `window.opener` ilişkisi korunuyor mu (sağlayıcının COOP başlığı)?
- iPhone Safari arka plandaki sekmeye mesajı teslim ediyor mu?
- Android'de ana ekran uygulaması bağlantıları ayrı pencerede açınca ilişki kopuyor mu?
- Ödeme sayfasındaki kart alanları otomatik tanınabiliyor mu?

## Mesaj kanalı: iki aday

**Kanal A — uygulama ödeme sekmesini açar.** Sanal POS, "Ödemeye geç"te
girişi isimli pencereye form POST'uyla açar ve pencere tutamacını saklar.
Kart sayfasında yer imi `window.opener`'a "hazır" mesajı yollar. Uygulama,
`event.source` kendi açtığı tutamaç ve `event.origin` DenizPay ise bekleyen
işin kartını gönderir. Sekme değişmediği için en akıcı kullanım budur.
Arka plandaki sekmenin mesajı işleyip işlemediğine bağlıdır.

**Kanal B — yer imi Sanal POS'u açar.** Yer imi rastgele istek kimliğiyle
(adresin `#` bölümünde, sunucuya gitmez) Sanal POS'un `/doldur` sayfasını
açılır pencerede açar. Kullanıcı orada cari/kartı görür ve "Doldur"a basar.
Uygulama kartı `opener`'a yalnız DenizPay hedef kökeniyle gönderir ve
pencereyi kapatır. Her doldurmada taze kullanıcı onayı vardır. Flutter'ın
yüklenme süresi (birkaç saniye) eklenir.

Kanal, application katmanında bir port olduğu için cihaz başına seçilebilir.
Aşama 0 sonucu hangisinin (veya ikisinin) kullanılacağını belirler.

## Saklama yeri sorunu (iPhone)

iPhone'da ana ekrana eklenen web uygulamasının deposu Safari'den ayrıdır.
Kanal A ve B Safari sekmeleri arasında çalışır. Bu yüzden iPhone'da Sanal POS
Safari'de açılmalı ve kartlar orada eklenmelidir. Ana ekran simgesinin
Safari'de açılması (`display: browser` vb.) Aşama 0'da denenir. Ana ekran
uygulamasında daha önce eklenmiş tam kartlar Safari'ye taşınamaz; yeniden
girilir (cihaz kasasının bilinen kısıtı, [CIHAZ_KART_KASASI.md](CIHAZ_KART_KASASI.md)).
Android Chrome'da ana ekran uygulaması ve tarayıcı aynı profili paylaşır.

## Aşamalar

### Aşama T — temel (kod değişikliği yok)

Depo henüz hiç commit içermiyor (`git log` boş). Sürdürülebilirlik için önce
mevcut 0.4.1 durumu yerel ilk commit olarak kaydedilir; uzak depo seçimi
(özel GitHub deposu vb.) kullanıcıya sorulur. Gizli/yerel dosyalar
`.gitignore` ile dışarıda kalır; commit öncesi taranır.

### Aşama 0 — deneme yer imi (hiçbir bilgi doldurmaz)

Amaç: yukarıdaki bilinmeyenleri gerçek cihazda ölçmek.

- Uygulamaya "Telefon uyumluluk denemesi" ekranı eklenir. Kanal A için
  DenizPay giriş sayfasını **boş** isimli pencerede açar (form POST değil,
  bilgi yok); kanal B için `/deneme` yanıtlayıcısı vardır.
- Deneme yer imi yalnız şu soruları yanıtlayıp sayfanın üstünde gösterir:
  betik çalıştı mı, sayfa türü (giriş/diğer), `opener` var mı, A ve B'de
  karşılıklı mesaj gidip geldi mi, açılır pencere açılabildi mi.
- Alan raporu: görünür form alanlarının yalnız tür/`name`/`id`/`autocomplete`/
  uzunluk/yakın başlık bilgisi; **değer okunmaz**, rakamlar `#` ile maskelenir
  (CAL bup ekran raporu kuralı). Kullanıcı raporu kendisi kopyalayıp bize iletir.
- Gönderilen mesajlarda kişisel/kart bilgisi yoktur; ağ isteği yapılmaz.
- Çıkış ölçütü: iPhone Safari ve Android Chrome'da sonuçlar kayıtlı; kanal
  seçimi ve alan tanıma yöntemi kararlaştırılmış.

### Aşama 1 — otomatik giriş

- "Ödemeye geç" → güncel sunucu doğrulaması (mevcut `PosServisi.dene`) →
  geçici form POST ile `login.aspx`. Kullanıcı adı = VKN/TC, şifre mevcut
  `posGirisSifresi` kuralı. Form alanları gönderimden hemen sonra boşaltılır
  ve kaldırılır. URL/referrer'da sır yoktur.
- CSP `form-action 'none'` yalnız `https://denizpay.bupilic.com.tr` için açılır.
- Aşama 0'dan bağımsız olarak önce yayımlanabilir; iki aşamada da bir sonuç verir.
- Giriş sonucu okunamaz; başarı iddia edilmez. Önceki cari oturumundan çıkış
  uyarısı CAL bup'taki gibi gösterilir.

### Aşama 2 — kart sayfasını doldurma

- Bekleyen iş: `{istekId, cariId, cariSurumu, kartId, olusma, son}` — sır
  içermez, en çok 10 dakika geçerli, kart sayfası için **tek kullanımlık**.
  Kilit, oturum kapanması, cari/kart sürümü değişimi işi iptal eder.
- Gönderimden hemen önce sunucu profili ve kart referansı yeniden doğrulanır,
  sonra cihaz kasası açılır (mevcut `KartIslemleri.oku`).
- Paket yalnız izin listesindeki alanları taşır: kart numarası, kart
  üzerindeki ad, ay, yıl, isteğe bağlı telefon. Tutar, CVV (K1'e kadar),
  OTP, giriş şifresi ve cari bilgisi pakete giremez; domain testiyle korunur.
- Köken denetimi iki yönlüdür: uygulama yalnız sabit DenizPay kökeninden ve
  beklenen pencereden gelen mesajı kabul eder, `targetOrigin` hiçbir zaman
  `*` olmaz. Yer imi yalnız `location.origin` DenizPay ise ve yanıt Sanal POS
  kökeninden, kendi istek kimliğiyle gelirse çalışır.
- Alan tanıma: CAL bup `eklenti/alanKurallari.ts` ve `alanlar.ts` kuralları
  (görünürlük, tür/uzunluk, yaygın ASP.NET adları, başlık yazısı) taşınır.
  CVV/tutar/taksit/SMS/şifre/PIN alanları her yazmadan önce yeniden engellenir.
  Belirsiz veya eksik eşleşmede **hiçbir alan doldurulmaz**; kullanıcıya
  neden gösterilir. Gerekirse Aşama 0 raporuna göre tanıtma kipi eklenir.
- Yazma: yerel `value` ayarlayıcı + `input`/`change` olayları; form gönderimi,
  düğme tıklaması, `Enter` yok. Yer imi DenizPay deposuna, çerezine veya
  ağa hiçbir şey yazmaz; bittiğinde paket referansını bırakır.
- Yer imi sabit, küçük ve kendi içinde tamdır; uzaktan betik yüklemez
  (ödeme sayfasına güncellenebilir kod sokulmaz, CSP'ye takılmaz). Sürüm
  numarası taşır; uygulama eski sürümü görünce yeniden eklemeyi ister.
- Kurulum ekranı: iPhone Safari ve Android Chrome için resimli adımlar,
  kopyalama düğmesi. Android Chrome'da yer imi adres çubuğuna adı yazılarak
  çalıştırılır; bu kurulum ekranında anlatılır.

### Aşama 3 — fotoğraftan kart okuma

1. Kart formundaki alanlara `AutofillHints` (`cc-number`, `cc-exp-month`,
   `cc-exp-year`, `cc-name`) verilir. iPhone Safari'nin kendi "Kartı Tara"
   özelliği ve kayıtlı kart önerileri böylece çıkabilir. Bu özellik telefonda
   çalışır; görüntü bize gelmez.
2. Uygulama içi okuyucu (isteğe bağlı): `<input type=file accept=image/*
   capture>` (Permissions-Policy `camera=()` değişmez), yerel paketli
   Tesseract (CAL bup'taki yerel kurulum yöntemi, CDN yok), yalnız rakam ve
   tarih kalıbı, Luhn ve son kullanma denetimi, aday listesi, kullanıcı
   onayından önce hiçbir alana yazılmaz. Görüntü/ham OCR saklanmaz veya
   gönderilmez; okuyucu yalnız istenince yüklenir.
   Kabartma rakamlı kartlarda okuma zayıf olabilir; başarı oranı gerçek
   cihazda kullanıcıyla ölçülür, garanti verilmez.

### Aşama 4 — kalıcılaştırma

Belgeler (MIMARI, POS_KARARI, CIHAZ_KART_KASASI, bilgi sayfası), sürüm,
yayın öncesi kontroller ve kullanıcı kabul listesi güncellenir.

## Katman yerleşimi

- `domain/`: `DoldurmaPaketi` (izin listeli alanlar, serileştirme),
  `BekleyenOdeme` (süre, tek kullanım, iptal kuralları). Platform bilmez.
- `application/`: `OdemeHazirlama` servisi (doğrulama + kasa + paket);
  portlar `OdemeKanali` (A/B), `PosGirisFormu`, `BekleyenOdemeDeposu`.
- `data/`: web bağdaştırıcıları ve `web/odeme_kanali.js`; web dışı platformda
  kapalı bağdaştırıcı (mevcut `cihaz_kart_kasasi_kapali.dart` deseni).
- `ui/`: Ödemeye geç akışı, `/doldur` ekranı, kurulum ve deneme ekranları.
- `tools/yer_imi/`: yer imi kaynağı, küçültme, sürüm/özet üretimi.
- Bileşim yine `app.dart`'tadır; dosyalar 400 satırı aşmaz; mimari testi bu
  sınırları denetlemeye devam eder.

## Test ve yayın kapısı

- Dart birim testleri: paket izin listesi, CVV/tutar reddi, süre, tek kullanım,
  kilit/sürüm iptali, yanlış köken/kaynak reddi, eski yer imi sürümü.
- Tarayıcı testleri (Chromium + WebKit, `tools/tarayici/`): iki ayrı yerel
  köken — uygulama ve yapay DenizPay taklidi (giriş + kart sayfası). Sahte
  kökenden mesaj, yanlış istek kimliği, süresi geçmiş iş, ikinci doldurma,
  belirsiz alan, CVV/tutar alanlarının boş kalması, form gönderilmemesi.
- Ağ yalıtımı: testlerde `denizpay.bupilic.com.tr`'ye her istek engellenir
  ve engellenme sayısının sıfır olduğu doğrulanır (CAL bup `agYalitimi` deseni).
- Test kökeni yalnız test derlemesinde `--dart-define` ile verilir.
  `yayin_oncesi.mjs`, üretim paketinde ve yer iminde yalnız gerçek DenizPay
  ve Sanal POS kökenlerinin bulunduğunu, test kökeninin bulunmadığını denetler.
- WebKit testi iPhone Safari kabulü yerine geçmez; fiziksel cihaz kabulü
  kullanıcıdadır.

## Karar bekleyenler

- **K1 — CVV.** Varsayılan: ödeme anında elle yazılır. "Yalnız tutar" isteği
  için CVV'nin de saklanması gerekir; PCI DSS yetkilendirme sonrası CVV
  saklamayı şifreli olsa da yasaklar ([FAQ 1280](https://www.pcisecuritystandards.org/faqs/1280/)).
  Kullanıcı açıkça seçmeden eklenmez.
- **K2 — Kanal A/B.** Aşama 0 sonucuyla.
- **K3 — iPhone'da Safari kullanımı.** Ana ekran uygulaması yerine Safari
  sekmesi; mevcut "ana ekrana eklenen" kararını değiştirir.
- **K4 — Uzak depo.** Aşama T için.

## Riskler

- DenizPay sayfası değişirse doldurma durur; belirsizlikte doldurmama kuralı
  yanlış alana yazmayı önler, yer imi neden durduğunu söyler.
- Sağlayıcı yer imlerini/opener'ı engellerse o cihazda yalnız Aşama 1 kalır.
- Müşteri kart numaralarının cihazda tutulmasının sorumluluğu şirkettedir;
  PCI uyumluluk iddiası yoktur (mevcut kasa kısıtı).
- Ödeme sayfasının kendisi ele geçirilirse paketi alır; bu, elle yazmada da
  aynıdır. Sanal POS sitesi ele geçirilirse kartlar zaten risktedir; yer imi
  uzaktan kod çekmediği için risk ödeme sayfasına taşınmaz.
