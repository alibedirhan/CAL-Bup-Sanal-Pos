**0.4.0:** Cihaz kart kasası `application/KartKasasi` portuyla bağlandı;
Web Crypto/IndexedDB bağdaştırıcısı yalnız webde etkin, diğer platformda
kapalıdır. Saf kurallar/işlem tutarlılığı domain/application katmanındadır.
Tam kart UI/domain nesnesi yalnız cihaz kasasına gider; Firebase serileştirmesi
maskeli metadata ile sınırlı. CIHAZ_KART_KASASI.md ve OTURUM_NOTU günceldir.

# Mimari ve kabul edilen kararlar

**0.2.0 güncellemesi:** Giriş, kalıcı depo, yönetim ve sunucu kuralları eklendi.
Güncel altyapı [CANLI_ALTYAPI.md](CANLI_ALTYAPI.md), mobil ödeme kararı
[POS_KARARI.md](POS_KARARI.md) içindedir. Aşağıdaki 0.1.0 açıklaması ilk
önizlemenin geçmişidir. Canlı kurulum/yayın için OTURUM_NOTU'na bakın.

## Hedef ve mevcut sınır

18 Ekim 2026: kullanıcı ayrı Flutter projesini onayladı. İlk hedef Android
Chrome ve iPhone Safari üzerinden açılan, ana ekrana eklenen Flutter Web'dir.
CAL bup ile ortak kayıt veya otomatik aktarım yoktur. Her kullanıcının yalnız
atanmış carilerine erişmesi gereklidir.

0.1.0 bu akışın çalışan, yalnız yapay verili önizlemesidir. Hesap sistemi,
sunucu, kalıcı kayıt ve gerçek POS entegrasyonu henüz yoktur. Android/iOS
klasörleri Flutter iskeletidir; yerel mobil paketler derlenmedi.

## Bağımlılık yönü

`ui → application → domain`; `data → application/domain`.
`app.dart` bu parçaları birleştirir. Saf Dart modelleri ve servisleri Flutter,
Firebase, HTTP veya tarayıcı API'si bilmez. Arayüz `OturumModeli` üzerinden
servisle konuşur. `CariDeposu` ve `PosBaglantisi` değiştirilebilir portlardır.
Mimari testler bu sınırları ve 400 satır sınırını denetler.

`DemoDeposu` bellekte veri tutar; yenileme bütün değişiklikleri sıfırlar.
Farklı kullanıcıya ait sentetik kayıt, erişim sınırı testleri içindir.
İstemcide yapılan bu kontroller gerçek kullanıcı yetkilendirmesi sayılmaz.

## Akış ve kurallar

Cari ara/filtrele → profil → geçerli kart özeti seç → açık onay → geçiş denemesi.
Kart seçilmeden veya onay kutusu işaretlenmeden ilerlenmez. Son kullanım ayı
bitene kadar kart geçerlidir. Servis işlemden hemen önce cariyi, sahipliği,
sürümü, kart aidiyetini ve tarihi yeniden doğrular. Aynı anda tek işlem yapılır.
Silinen/değişen kayıtla eski seçim kullanılamaz. Başarı yalnız denemenin
tamamlandığı anlamına gelir; ödeme sonucu değildir.

Kart modeli yalnız etiket, son dört hane ve son kullanım tarihi içerir.
Gerçek kart ekleme formu yoktur. Demo kart düğmesi yapay özet oluşturur.
Cari kodu kullanıcı içinde benzersizdir. Silme onaylıdır. Veri deposundaki
sürüm kontrolü eski kaydın yeni değişikliği ezmesini engeller.

Arka plana geçiş ve 10 dakika hareketsizlik ekranı kilitler; açık modallar
kapanır, cari/kart seçimi bırakılır, geç dönen işlem yanıtları gösterilmez.
Bu bir ekran gizleme davranışıdır; belleği silmez, şifreleme veya gerçek
yeniden kimlik doğrulama sağlamaz. Üretim oturumu ayrıca tasarlanmalıdır.

## DenizPay girişi ve kart doldurma (0.6.0–0.7.0)

Canlı kipte seçim kontrolünden sonra (kart seçmek isteğe bağlı) "DenizPay’e
giriş yap" `PosGirisKapisi` portu üzerinden `web/pos_giris.js` ile sabit
`login.aspx`'e form POST'u yapar; CSP `form-action` yalnız DenizPay kökenidir.
Kart seçildiyse ve tam kart bu cihazın kasasındaysa `DoldurmaHazirligi` portu
(`web/doldurma.js`) yerel depoya 10 dakikalık `DoldurmaIsi` yazar: yalnız kasa
referansı, cari VKN/TC ve son zaman; kart, CVV, tutar yoktur. Elle "Ekranı
kilitle", çıkış/hesap değişimi ve kartsız giriş işi siler; sekme değişimi ve
boşta kilidi silmez (DenizPay sekmesine geçmek akışın parçasıdır). DenizPay kart sayfasında "BUP Doldur" yer imi
(`tools/yer_imi/doldur.js`, kurulum `web/kurulum.html`) `doldur.html`'i açar;
bu sayfa işi okur, kartı kasadan çözer ve yalnız DenizPay kökenine
`postMessage` ile yollar. Yer imi yalnız `number`, `name`, `expiry` kutularına
yazar; sayfadaki "Firma İsmi" numarası işteki VKN/TC ile aynı değilse hiçbir şey
yazmaz. CVV/tutar/düğmelere dokunmaz, formu göndermez, uzaktan kod yüklemez.
Kart doldurma anında sunucu yeniden sorgulanmaz; yetki, işin kurulduğu andaki
sunucu doğrulaması ve 10 dakikalık süredir (bilinçli ödünleşim).

## Web paketi

Flutter/Dart ve bağımlılık kilit dosyaları projeye aittir. Yazı tipleri ve
CanvasKit kendi paketindedir. Roboto adı ayrıca Flutter motorunun varsayılan
font isteğini yerel dosyaya yöneltir. CDN'ye çalışma zamanı bağımlılığı yoktur.
Manifest ve iOS ana ekran simgeleri hazırdır. Manifest `display: browser`
(0.7.2): simge Safari/Chrome sekmesi açar; iPhone'da ayrı (standalone) web
uygulamasının deposu Safari'den ayrı olduğu için kart kasası ve "BUP Doldur"
işi orada görünmez. Service worker/offline iş kaydı
yoktur; çevrimdışı ödeme kuyruğu oluşturulmaz. İlk açılış bağlantı gerektirir.

Derleme giriş dosyaları içerik hash'i ile sürümlenir. Önizleme sunucusu sadece
`build/web` sunar; loopback adresine bağlıdır. No-store ve CSP başlıkları
yalnız aynı kaynaktan çalışmaya izin verir. Üretim hosting bu başlıkları
ayrıca uygulamalıdır; yerel sunucu üretim sunucusu değildir.

## Canlı sürüm için sonraki uygulama

1. Sağlayıcının resmi mobil web/hosted ödeme/token veya API desteği belgelenir.
   CAL bup'ın masaüstü MV3 doldurma yardımcısı mobil çözüm sayılmaz. Belgelenmiş
   yöntem yoksa otomatik kart doldurma/ödeme vaat edilmez. Gerçek sağlayıcıya
   deneme isteği atılmaz; varsa yetkili sandbox üzerinden geliştirilir.
2. Ayrı hesap/veri alanı seçilir. İstemci kullanıcı kimliğine güvenmeyen sunucu
   her liste/okuma/yazmada doğrulanmış oturum ve cari atamasını denetler.
   İstemci yalnız yetkili kayıtları alır; tüm carileri indirip gizlemez.
   Atama yönetimi, yetki iptali, oturum süresi ve yeniden doğrulama eklenir.
3. Kalıcı depoda atomik sürüm kontrolü, şema geçişleri, yedek/geri yükleme ve
   hassas alan içermeyen denetim kayıtları kurulur. Kapsamsız/başka kullanıcı
   erişimi, silme/yazma ve görev iptali sunucu/emülatör testleriyle doğrulanır.
4. Ödeme özelliği gerekiyorsa sağlayıcı oturum kimliği, tekrar gönderimde tek
   işlem, imzalı sonuç doğrulama, tutar/para birimi ve zaman aşımı sunucuda
   uygulanır. Demo sonucu gerçek işlem sonucu olarak tekrar kullanılmaz.
5. Ayrı HTTPS adresinde test yayını ve gerçek cihaz kabulü yapılır. Android
   ve iPhone'da ana ekrana ekleme, klavye, sekmeden dönüş, erişilebilirlik,
   yavaş ağ/cihaz ve sağlayıcı yönlendirmeleri sınanır. Fiziksel cihaz ölçümü
   olmadan “kasma olmaz” garantisi verilmez.

Firebase zorunlu seçilmedi. Sunucu/sağlayıcı bağımlılıkları gerçek gereksinim
netleşince portların arkasına eklenir. CAL bup'ın Firebase ayarları taşınmaz.
