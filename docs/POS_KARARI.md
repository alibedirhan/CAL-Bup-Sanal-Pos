# Mobil POS kararı — 18 Ekim 2026

> **Güncel değil (21 Ekim):** 0.6.0'dan beri otomatik giriş, 0.7.0'dan beri
> "BUP Doldur" kart doldurma var. Güncel akış `MIMARI.md` "DenizPay girişi ve
> kart doldurma", plan `MOBIL_DOLDURMA_PLANI.md`. Aşağısı tarihsel kayıttır.

## 0.4.1 güncel geçiş kararı — 19 Ekim 2026

Kullanıcı artık ana sayfa yerine doğrudan
`https://denizpay.bupilic.com.tr/login.aspx` adresinin açılmasını istedi.
Sabit HTTPS bağlantısı, güncel seçim kontrolünden sonra ayrı kullanıcı
tıklamasıyla yeni sekmede açılır; URL'ye kart/kimlik/şifre eklenmez.
Aşağıdaki ana sayfa üzerinden giriş tercihi tarihsel karardır.

Kullanıcı yalnız tutar girilecek otomatik giriş/kart/CVV akışı da istiyor.
Mevcut dış tarayıcı web akışı bu alanları doldurmaz; ekranda açıkça yazılır.
DenizPay'a istek veya gerçek giriş/ödeme testi yapılmadı. Sağlayıcı
entegrasyon desteği doğrulanmış değildir. Yeni sürüm bu gereksinimin
karşılandığı anlamına gelmez.

CVV, belirli bir ödeme için işlem anında alınabilir; sonraki ödemeler için
saklanmaz. PCI DSS, yetkilendirme sonrasında şifreli olsa veya müşteri izin
verse bile saklamaya izin vermez. Bu nedenle cihaz kart kasasına CVV alanı
eklenmedi. Kaynak: [PCI SSC FAQ 1280](https://www.pcisecuritystandards.org/faqs/1280/).
Tarayıcı sınırı: [MDN same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Same-origin_policy).

Önerilen sonraki adım: sağlayıcının kayıtlı kart/token veya resmi mobil
ödeme desteğini teknik belge ve yetkili sandbox ile doğrulamak. Destek
varsa kart sağlayıcıda kalır; biz cari/kart referansı ve tutarla akışı
başlatırız. 3D Secure/CVV gereksinimini sağlayıcı belirler; yalnız tutar
sözü verilmez. Resmi destek yoksa yerel Android/iOS uygulaması ve izinli
WebView seçeneği ayrıca değerlendirilir; yalnız WebView eklemek uyum veya
güvenlik kanıtı değildir. Kullanıcı henüz yerel dağıtım yolunu seçmedi.

## 0.4.0 kart kasası kararı

Kullanıcı kart numarasını cihazda saklamayı ve ikinci parola istememeyi seçti.
Tam kart formu + Web Crypto/IndexedDB kasası eklendi; Firebase yalnız maskeli
özeti alır. Ayrıntı CIHAZ_KART_KASASI.md. Bu, aşağıdaki 0.2.0 sürümünün tam
numara toplamama kapsamını değiştirir. CVV/OTP saklanmaz. Otomatik mobil
POS giriş/kart doldurma, token/API ve gerçek sağlayıcı kabulü hâlâ tamamlanmadı.

## Kullanıcının istediği sonuç

CAL bup'taki gibi cariyi seçip vergi/kimlik numarasıyla giriş hazırlamak ve
seçili kartın bilgilerini ödeme formuna aktarmak. Güvenlik öncelikli.
Kullanıcı önce Bupiliç ana sitesindeki Online İşlemler → Online Ödeme yolunu
başlangıç olarak belirtti; 0.4.1’de doğrudan DenizPay girişini istedi.
Ödeme adresi değişirse yeni bağlantıyı bildirecek.

Ana sitenin HTML'i 18 Ekim'de yalnız okunarak kontrol edildi; ödeme bağlantısı
`https://denizpay.bupilic.com.tr/login.aspx` idi. **Bu ödeme adresine istek,
giriş, müşteri/kart/ödeme/SMS denemesi yapılmadı.** Canlı kartla test yapılmaz.

## 0.3.0 kullanıcı açıklaması

POS girişi VKN veya TC ile yapılır. Kullanıcı, sağlayıcı giriş şifresinin
numaranın ilk iki ve son iki hanesi olduğunu bildirdi. Bu kural gerçek
sağlayıcıya istek atılarak doğrulanmadı; kullanıcı beyanına dayanır. Uygulama
giriş şifresinden (minimum 6 karakter) ayrıdır. Cari kodu arayüzden kaldırıldı,
yeni cari için VKN/TC zorunlu. Mevcut kayıtlardaki eski kod metadata alanı
uyumluluk için korunur; kullanıcıdan istenmez veya gösterilmez.

“POS şifresini kopyala” düğmesi bu dört haneyi yalnız kullanıcı tıkladığında
hesaplayıp panoya yazar. Ekrana kendiliğinden yazılmaz; Firestore, localStorage,
günlük veya URL'ye şifre eklenmez. Bu, tarayıcıda POS formunun otomatik
doldurulduğu anlamına gelmez. Eski 0.2.0'daki “türetilmez” ve “kimlik isteğe
bağlı” açıklamaları o sürümün tarihsel kapsamıdır.

## Teknik sınır

CAL bup masaüstü Chrome/Edge'de MV3 yardımcıyla farklı kökendeki formu doldurur.
Mobil web uygulaması aynı yetkiye sahip değildir. Dış Safari/Chrome'da açılan
sayfanın formunu Flutter Web'den dolduramayız. Ana siteden gelmek bu sınırı
değiştirmez. Tarayıcı otomatik doldurması, işletim sistemi desteği ve sağlayıcı
formunun uyumuna bağlıdır; uygulamadaki kart seçimiyle otomatik eşleşme iddiası
yapılmaz.

Öncelik resmi entegrasyon/token/hosted akışı olmalıdır. Bu özel DenizPay
uygulamasının API/SSO/token desteği henüz doğrulanmadı. İzinli Android/iOS
WebView alternatifi değerlendirilebilir; resmi `webview_flutter` bu
platformları destekler, ancak bu tek başına sağlayıcı uyumu/güvenliği/ödeme
kabulü sağlamaz. Dağıtım, 3D Secure, SMS, arka plana geçiş ve izinli hedef
denetimi ayrıca gerekir. Kullanıcı henüz yerel uygulama dağıtımını seçmedi.

## 0.2.0'da yapılan

POS şifresi/tam PAN/CVV/OTP alınmaz, türetilmez, saklanmaz veya günlüğe yazılmaz.
Kartlar yalnız etiket/son dört hane/tarih özetidir. Vergi/TC numarası isteğe
bağlı, yalnız biçim kontrolüyle (10/11 rakam) saklanır; gerçek kimlik
doğrulaması veya numaranın sahibini doğrulama iddiası yoktur.

Güncel cari ve kart sunucudan doğrulandıktan sonra **ayrı bir kullanıcı
tıklamasıyla** Bupiliç ana sitesi açılır. URL'ye cari/kart/şifre eklenmez.
Kullanıcı resmi sitedeki ödeme yolunu izler. Bu özellik, talep edilen tam
otomatik aktarımın tamamlandığı anlamına gelmez; ekranda açıkça belirtilir.
Ödeme başarılı/başarısız durumu uygulama tarafından tahmin edilmez.

Ödeme/giriş hedefi kendiliğinden değiştirilemez. Yeni bağlantı geldiğinde resmi
kaynağı ve HTTPS kökeni kontrol edilir, izin listesi gerekiyorsa açık sürüm
değişikliğiyle güncellenir. Ana sayfa HTML'inden çıkan keyfi adrese sır aktarımı
yapılmaz. 0.2.0’daki sabit hedef `https://www.bupilic.com.tr/` idi; 0.4.1 kararı
bunu yukarıdaki DenizPay giriş adresiyle değiştirir.

## Sağlayıcıdan gereken teknik bilgiler

1. Bu kuruma ait DenizPay için resmi API/SDK, signed SSO veya mobil hosted
   ödeme akışı var mı? Teknik belge ve yetkili test/sandbox ortamı nedir?
2. Kart sağlayıcı tarafında kayıtlı kalıp yalnız token/referans ile seçilebilir
   mi? Token kapsamı, süre/iptal ve cari ilişkisi nasıl doğrulanır?
3. 3D Secure, SMS, dönüş adresleri ve sunucuda imzalı sonuç doğrulaması nasıl
   çalışır? Tutar/para birimi, tekrar gönderimde tek işlem garantisi nedir?
4. Sistem tarayıcısı ve yerel WebView kullanımı için destek ve izin sınırları
   nedir? Resmi giriş kökeni/rota değişikliği nasıl duyurulur?

Bu sorular kimseye otomatik gönderilmedi. Yetkili teknik yanıt olmadan
ödeme API'si, form seçicileri veya otomatik giriş/ödeme davranışı uydurulmaz.

Kaynaklar: [Flutter WebView](https://pub.dev/packages/webview_flutter),
[PCI token yaklaşımı](https://www.pcisecuritystandards.org/faqs/1384/),
[PCI doğrulama kodu saklama sınırı](https://www.pcisecuritystandards.org/faqs/1533/),
[Apple otomatik ödeme bilgisi doldurma](https://support.apple.com/en-mide/guide/iphone/iphf101498e9/ios),
[Chrome otomatik doldurma](https://support.google.com/chrome/answer/142893?hl=en).
