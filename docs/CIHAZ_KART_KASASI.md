**Android (27 Ekim 2026):** aynı sözleşme `lib/data/kasa/sifreli_kasa.dart`'ta
platformdan bağımsız uygulanır; şifreleme Android Keystore'dadır (kullanıcı
başına dışa aktarılamaz AES-256-GCM, StrongBox varsa, yalnız telefon kilidi
açıkken; ekran kilidi olmayan telefonda kart saklanmaz). Kayıtlar yedeğe/cihaz
aktarımına girmeyen klasörde, kullanıcı başına tek JSON belgesindedir. Ayrıntı ve
doğrulama `docs/ANDROID_PLANI.md` "Durum". Aşağısı web kasasıdır.

# Cihazdaki kart kasası — 0.4.0

## Kullanıcının açık kararları

18 Ekim 2026: CAL bup gibi her cariye birden fazla kart istedi. Ayrı kasa
parolası istemedi. Sorulduğunda tam numaraların şimdilik yalnız eklendiği
cihazda kalmasını seçti. Önceki PAN formu kısıtı bu yeni kapsam için değişti.
Uygulama hesabı/aktif profil, yalnız atanmış cari ve mevcut ekran kilidi sürer.

Kart adı, tam numara, kart üzerindeki ad, ay/yıl ve isteğe bağlı Türkiye cep
telefonu girilir. CVV/OTP alanı yoktur. Numara biçim/Luhn denetimi kartın
sahibini veya bankada geçerli olduğunu doğrulamaz. Her caride en fazla 10 kart.
Kart seçmek ödeme/SMS başlatmaz; banka telefonunu değiştirmez. Otomatik POS
form doldurma tamamlanmış değildir. Gerçek POS'a deneme isteği atılmadı.

## Bulut ve cihaz sınırı

Firebase kart belgesinde yalnız id, etiket, son dört, ay, yıl ve isteğe bağlı
`cihazKayitId` bulunur. Referans rastgele UUID'dir; anahtar veya kart tokeni
değildir. Tam numara, kart üzerindeki ad ve telefon bu sınıra girmez.
Sunucu alan whitelist'i bunları ve CVV'yi reddeder. Kart adı kutusuna uzun
numara yazılması da yeni yazmalarda engellenir. Eski özetler okunabilir.
Gerçek CAL bup kayıtları/yapılandırması taşınmadı.

Yerel `bup-pos-cihaz-kasasi` IndexedDB veritabanında her kullanıcıya ait
Web Crypto AES-GCM 256 bit `CryptoKey`, anahtar deposuna `extractable=false`
olarak yazılır. Her şifreleme yeni 96 bit rastgele IV ve 128 bit doğrulama
etiketi kullanır. Ek doğrulama verisi şema, kullanıcı, cari, kart, son dört,
tarih ve opak referansı bağlar. Numara/sahip/telefon yalnız şifreli JSON'dadır.
Kalıcı localStorage/sessionStorage içine kart konmaz. JS modülü ağ kullanmaz;
tarayıcı istisnası veya kart değeri günlüğe yazılmaz.

Bu **parolasız cihaz saklamasıdır**: anahtar aynı tarayıcı profilindedir.
Fiziksel cihazın, işletim sisteminin veya aynı kökende çalışan kodun ele
geçirilmesine karşı donanım kasası/ayrı parola güvencesi vermez. Nonextractable,
yalnız Web Crypto dışa aktarma API'sini kısıtlar; açık verinin bellekte hiç
bulunmadığı veya profil dosyası hırsızlığına dayanıklılık anlamına gelmez.
PCI uyumluluk/sertifikasyon iddiası yoktur.

Tarayıcı/cihaz değişikliği, özel sekmenin kapanması, uygulama depolamasının
silinmesi/atılması veya farklı PWA saklama bölümü tam bilgiye erişimi
kaybettirebilir. Buluttaki maskeli özetten tam numara kurtarılamaz. Kullanıcı
bu durumda numarayı yeniden girer. Yerel veri aktarımı/yedeği yoktur.

## İşlem tutarlılığı

Önce yeni, şifreli bir taslak yazılır; önceki etkin kayıt henüz değiştirilmez.
Rastgele referans sonra sunucudaki kart özetiyle aynı sürüm kontrollü cari
transaction'ında saklanır. Sunucu reddederse eski etkin yerel kayıt korunur.
Sunucu yanıtı belirsizse şifreli taslak silinmez; gerçekten sunucuya ulaşmış
referansla sonraki yetkili okumada kurtarılabilir. Son yerel adım tamamlanamazsa
başarı sahte hataya çevrilmez; kaydedildiği ve yeniden açılması gerektiği anlatılır.

Açılışta güncel sunucu profili/kart referansı doğrulanır; sonra yerel şifre
çözülür. Kart değişmiş/silinmişse veya hesap kilitlenmişse açık sonuç gösterilmez.
Bozuk/anahtarı eksik kayıt sessiz sıfırlanmaz, düz metin yedeğine düşülmez.
Yazma anahtarı ilk iki eşzamanlı hazırlamada tek IDB transaction'ıyla seçilir.
IDB yazmaları Safari için aynı işlem olayında callback ile zincirlenir.

Silmede önce sunucu onayı alınır, ardından bu kullanıcı/cari/kartın etkin ve
taslak yerel kayıtları silinir. Yerel silme aksarsa kısmi sonuç uyarısı vardır;
sunucu silinmişken başarısız diye tekrar kayıt yaptırılmaz. Başka cihazdaki
şifreli kopyanın uzaktan fiziksel olarak silindiği iddia edilmez. Yeni yetkili
sunucu okuması olmadan bu kopya uygulama ekranından açılmaz. Daha önce açık
veriyi bilen kişinin bunu unuttuğu/eldeki kopyasının yok edildiği garanti edilemez.

Form varsayılan olarak numarayı maskeler; yalnız “göster” eylemi açar. Hesap
kilidi/atama değişince formun numara/ad/telefon alanları temizlenir ve gizlenir.
Tam kartı panoya kopyalama/otomatik ödeme yoktur. Dart/JS metin belleğinin
kriptografik olarak sıfırlandığı iddia edilmez. Ağ bağlantısı ve yetki kontrolü
gereklidir; çevrimdışı ödeme kuyruğu oluşturulmaz.

## Doğrulama

Saf Dart testleri biçim/Luhn, telefon, bulut serileştirme sınırı, sunucu reddi,
son yerel adım hatası, kilit/eski referans/silme koşullarını kapsar.
`npm --prefix tools/tarayici run test:kasa`: Chromium ve WebKit'te gerçek
Web Crypto/IndexedDB; anahtar dışa aktarma reddi, yenileme, taslak kurtarma,
eşzamanlı anahtar oluşturma, hesap/cihaz ayrımı, AAD/cipher bozulma reddi ve silme.

Gerçek SDK + Auth/Firestore emülatörü kabulü formdan çoklu kart eklemeyi,
yenilemede cihazdan geri açmayı, düzenlemeyi, diğer tarayıcı profilinde tam
numaranın bulunmamasını ve kullanıcı atama/erişim iptalini kapsar. Sunucu kural
testi düz metin hassas alanları reddeder. Testler yalnız yapay kartlarla;
gerçek şirket/kart/ödeme denemesi yapılmaz. Fiziksel iPhone kabulü kullanıcıdadır.

Kaynaklar: [Web Crypto AES anahtarı](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/generateKey),
[CryptoKey sınırları](https://developer.mozilla.org/en-US/docs/Web/API/CryptoKey),
[CVV saklama sınırı](https://www.pcisecuritystandards.org/faqs/1280/).
