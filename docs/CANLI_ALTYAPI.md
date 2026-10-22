# 0.4.0 cihaz kart kasası

Kullanıcı tam kartı yalnız eklendiği cihazda, ayrı parola olmadan saklamayı
seçti. Cari ve maskeli kart özetleri Firebase'de kalır; PAN/kart üzerindeki
ad/telefon yalnız bu tarayıcıdaki şifreli kasadadır. Yeni kart formu/yerel
kripto portu, yazma tutarlılığı, saklama kaybı ve yetki sınırları için
[CIHAZ_KART_KASASI.md](CIHAZ_KART_KASASI.md) okuyun. Aşağıdaki 0.3.0 ve 0.2.0
“tam numara alınmaz” açıklamaları tarihsel kapsamdır. CVV/OTP hâlâ alınmaz.

---

# 0.3.0 kayıt akışı güncellemesi

Cari kodu form/listelerde yok; yeni girişte VKN/TC zorunludur. Eski Firestore
kod/rezervasyon şeması uyumluluk için korunur. Yeni kayıtlarda rezervasyon
anahtarı VKN/TC'den gelir; aynı kullanıcıda eşzamanlı tekrar oluşturma atomik
rezervasyonla engellenir. Görünen mevcut kayıtlardaki aynı numara formdan da
reddedilir. Eski kodla kayıtlı carilerde global VKN benzersizliği için geçmiş
veri göçü yapılmadı; eski kayıtlar değiştirilmedi.

Sunucu işlemi onayladıktan sonra cari/kart ekleme, düzenleme, yıldızlama veya
silmenin başarısı ayrı liste/profil okumasına bağlanmaz. Doğrulanmış işlem
sonucuyla ekran güncellenir; canlı sunucu akışı devam eder. Ağ okumasının
gecikmesi artık onaylanmış yazmayı başarısız göstermiyor. Okuma/yazma zaman
aşımı bağlantı/sonuç belirsizliği olarak ayrı mesaj verir; veri bozukluğu diye
sınıflanmaz. Yazma sürerken yalnız geçici bağlantı metadata olayı yok sayılır;
yetki iptali ve kilit geç gelen sonucu hâlâ geçersiz kılar.

Kullanıcının iPhone/Safari'de bildirdiği hata kayıt sonrası görüldü; kullanıcı
yenilemede carinin listede olduğunu doğruladı. Sunucudan yalnız dar kapsamlı
alan türleri kontrol edildi, gerçek değerler günlüğe/kaynağa alınmadı. Kesin
fiziksel cihaz istisnası/stack'i elde edilmedi; olası zaman aşımı ve kayıt
sonrası tekrar okuma koşulu yapay testle kapsandı. Gerçek Safari yeniden
kullanım kabulü kullanıcıdadır.

POS şifresi kullanıcı beyanıyla ilk iki+son iki hane; açık düğmeyle panoya
kopyalanır, saklanmaz. Güncel ödeme sınırları POS_KARARI'ndadır.

---

# 0.2.0 giriş, veri ve yayın altyapısı

## Ayrı kaynaklar

Yeni Firebase projesi `bup-sanal-pos-izmir`; tek web uygulaması ve
europe-west3 Standard/ücretsiz Firestore veritabanı. Billing durumu API'den
kapalı olarak doğrulandı. Mevcut `bup-siparis` projesine veya kayıtlarına
yazılmadı. Cloud Functions/Blaze/ücretli hizmet açılmadı.

Kullanıcı e-posta/şifre girişini seçti; iş hesaplarını yönetici açar.
İstemcide kayıt ol ekranı yoktur. Auth uç noktasından tek başına bir kimlik
oluşturmak iş verilerine erişim vermez: ayrıca yönetici tarafından oluşturulmuş
aktif `kullanicilar/{uid}` profili gerekir. Spark üzerinde yönetim ekranı
ikincil, bellekte Auth oturumuyla yeni kimliği açar; asıl yönetici oturumu
değişmez. Bu, herkese açık Auth kayıt API'sinin kapatıldığı iddiası değildir.

Yönetici rolü istemciden edinilemez. İlk yönetici, yerel Firebase CLI sahibinin
yetkisiyle ayrı yönetim aracından açılır. E-posta kullanıcı mesajında verilmiştir;
testlerde/kaynaklarda kullanılmaz. Şifre rastgele oluşturulur ve gösterilmez;
kullanıcının kendi şifresini belirlemesi için bağlantı yalnız proje dışındaki
0600 izinli yerel dosyaya yazılır. Otomatik e-posta gönderilmez.

## Sunucu kuralları

`kullanicilar`: kişi kendi profilini okuyabilir. Liste/hesap profili açma ve
satıcı erişimi değiştirme yöneticide. Yönetici kendisini kapatamaz, başka
yöneticiyi değiştiremez; istemciden rol yükseltme yoktur. Yönetici yönetim
ekranında bütün atamaları görebilir; normal ana liste yalnız kendi atamalarıdır.

`cariler`: yalnız aktif kullanıcı + atanmış sahip veya yönetici erişir.
Satıcı atamayı değiştiremez. Liste sorgusu sahip ve `silindi=false` koşulludur;
tüm kayıtları indirip tarayıcıda gizleme yoktur. Aktif olmayan hesaba atama
yapılmaz. Her yazma sürümü tam bir artırır ve sunucu zamanı kullanır.

`cariKodlari`: kullanıcı içindeki büyük/küçük harf duyarsız kodun rezervasyonu.
Cari, rezervasyon ve `denetim` kaydı aynı işlemde değişir. Rezervasyon tek
başına bırakılamaz veya başka cariye geçirilemez. Atama/silme de atomiktir.

`denetim`: yalnız aktör UID, cari ID, sürüm, işlem türü ve sunucu zamanı.
`posGirisleri`, `posIslemleri` (0.9.0): yalnız eklenen tahsilat kayıtları;
ayrıntı [TAHSILAT.md](TAHSILAT.md).
Kart, kimlik numarası, ad, şifre veya telefon içermez. Değiştirilemez.
Operasyon geçmişidir; ödeme kaydı veya banka sonucu değildir.

Kartlar cari belgesinde en fazla 10 özet olarak tutulur. Her işlem en fazla
bir yeni/değişen özeti kabul eder; `sonKart` ve küme farkı birlikte denetlenir.
Bu, on kartı her güncellemede yeniden doğrulayıp Firestore'un 1000 ifade
sınırını aşmayı önler. Geçerli ilk veri boş kart listesiyle oluşturulur;
sonraki bütün yeni öğeler şemadan geçer. PAN/CVV gibi ek alanlar reddedilir.
Silme aktif listeden kaldırır, kart özetlerini temizler ve kodu serbest bırakır;
silinmiş cari metadata ve denetim geçmişi yönetim için sunucuda kalır.

## Oturum ve ağ

Auth yalnız tarayıcı oturumunda kalır (`SESSION`). Şifre alanları işlemden
sonra bırakılır. Firestore kalıcı tarayıcı önbelleği kapalıdır; çevrimdışı
yazma/ödeme kuyruğu yoktur. İşlemler transaction veya açık sunucu okumasıdır.
Snapshot akışları atanmış kaydın kaldırılmasını ve profil yetki iptalini izler.
Sunucu doğrulaması kaybolursa veri ekranı kapatılır; yazma yetkisi ayrıca
her istekte sunucuda denetlenir.

Arka plana geçiş ve 10 dakika hareketsizlik çalışma alanını kapatır; yeniden
açılışta Firebase parola doğrulaması + güncel erişim kontrolü gerekir.
Bu, cihaz belleğinin kriptografik olarak silindiği iddiası değildir.
Şifre değiştirme mevcut şifreyi yeniden doğrular. Üretim şifre politikası
6–128 karakter olarak sunucuda uygulanmalı ve yayın kapısından geçmelidir.

## Tarayıcı paketi

FlutterFire JS SDK sürümü, kilitli `firebase_core_web` paketinden derlemede
okunur. Canlı/emülatör açılışı dış modülden SDK'ları sırayla yükler; satır içi
betik veya `unsafe-inline` script izni gerekmez. SDK Google gstatic kaynağından gelir; Auth yardımcı iframe’i için
Google apis.google.com betiğine de CSP izni gerekir; fontlar/CanvasKit yereldir. Demo Firebase'i başlatmaz.

Emülatör testinde Auth, Flutter başlamadan aynı SDK ayarlarıyla yerel adrese
bağlanır; sayfa yenilemede gerçek Auth'a yanlışlıkla istek atılması engellenir.
Gerçek sunucu çağrıları ve güvenlik kuralları taklit edilmez; Firebase
emülatörüne gider. WebKit, SDK'nın isteyerek iptal ettiği RPC'leri bazen sayfa
hatası olarak raporlar. Test yalnız aynı yerel Listen/Write RPC oturumu
(kaynak/yol, VER, database, RID, SID, CI, TYPE) ayrıca “Load request cancelled”
olarak doğrulanırsa iptali ayırır. WebKit hata ve ağ olayında farklı AID/zx/t
değerleri verebilir. Diğer sayfa hataları
testi düşürür. Canlı pakette emülatör ayarları bulunmaz. Fiziksel Safari kabulü
ayrıca gerekir.

## Operatör komutları ve kalan kurulum

```sh
python3 tools/firebase_ayar.py
# Firebase konsolunda Authentication → Başlayın işlemi bir kez gerekir.
node tools/sunucu-test/auth_duzenle.mjs
cd tools/sunucu-test
node yonetici.mjs ilk-yonetici EPOSTA /proje-disi/ilk-giris.html
cd ../..
bash tools/yayin.sh
```

İlk Auth kurulumu bu not yazılırken kullanıcıya soruldu. Kaynağın hazırlanması,
kuralların sunucuya yüklenmesi ve Hosting yayını farklı adımlardır; güncel
tamamlanma durumu OTURUM_NOTU'nun en üstündedir. Yayın kapısı yanlış proje,
demo/emülatör kipi, billing açık veya giriş/politika eksik koşulunda durur.
Hosting yalnız `build/canli` sunar. Diğer projelerin adresine yayın yapılmaz.

Gerçek cihaz kabulü, sağlayıcının otomatik aktarımı ve işletme yedek/geri yükleme
iş akışı ayrı tamamlanması gereken işlerdir; yerel testten tamamlandığı sonucu
çıkarılmaz. Gerçek kart veya şirket kaydıyla test yapılmadı.
