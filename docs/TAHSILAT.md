# Tahsilat kaydı ve gün sonu (0.9.0, 0.10.0, 0.10.1)

Kullanıcı isteği (22 Ekim 2026): bir cariyle DenizPay'e girilip alınan ödeme
kesin olarak o cariye yazılsın; 24 saatteki bütün işlemler tarih, saat ve cari
adıyla kaydedilsin; gün bitince gün sonu kendiliğinden oluşsun. Proje
yöneticilere sunulacak: güvenli, sağlam, denetlenebilir olmalı.

## Bilinen gerçekler

- DenizPay'e hangi carinin VKN/TC'siyle girildiyse tahsilat LED'de o cariye
  kendiliğinden eklenir (kullanıcı). Doğru cari = DenizPay'e doğru cariyle girmek.
- Sonuç ekranı (kullanıcı görüntüleri): başarılıda **Onay Formu** — Açıklama
  ("Ödeme Başarıyla Gerçekleştirildi"), Üye Sipariş Numarası, Pos Sipariş
  Numarası ("VP…"), Tutar. Başarısızda **Hata Formu** — Açıklama ("3D Şifresi
  Yanlış."), Pos Sipariş Numarası, Tutar. Tutar biçimi değişken: "4500",
  "45678,90". Sayfa HTML'i görülmedi.
- DenizPay kart sayfasında "Firma İsmi : … (VKN)" yazar (yer imi okur).
  Sonuç ekranında firma numarası olup olmadığı bilinmiyor (☰ görüntüsü bekleniyor).
- DenizPay oturumu çerezle tarayıcı genelinde tutuluyor olabilir (son giriş
  geçerli); doğrulanmadı. Bu yüzden eski sekmedeki ödeme belirsiz sayılır.
- Sanal POS oturumu yalnız açık olduğu sekmededir (`Persistence.SESSION`,
  güvenlik kararı). DenizPay'den açılan sekme sunucuya yazamaz.

## Akış

1. "DenizPay'e giriş yap": DenizPay açılmadan önce giriş bu telefonun **açık
   girişler** listesine eklenir (`web/acik_giris.js`; son 10, her biri 2 saat:
   cari id/ad/VKN, kartın son dört hanesi, giriş kimliği, an). Sunucuya
   `posGirisleri` kaydı gider. "Boş giriş sayfasını aç" ve bu sekmede çıkış
   listeyi siler (elle girilen carinin kim olduğu bilinmez); başka hesapla
   girişte o hesabın girişleri atılır. Yeni açılan Sanal POS sekmesi önce
   oturumsuz başlar ama listeyi silmez (0.10.1; silseydi DenizPay'de süren
   ödemenin sonucu cariye bağlanamazdı).
2. Kart sayfasında "BUP Doldur" (yer imi 3): kartı yazmanın yanında sayfadaki
   firma VKN'sini **o DenizPay sekmesinin** `sessionStorage`'ına not eder
   (`bup-sekme-firma` {vkn, an}; sekmeye özel, başka sekmeye geçmez).
3. Sonuç ekranında "BUP Doldur": etiketli kutuların yazısı, sayfa metni, sayfadaki
   firma numarası ve sekme notu `sonuc.html`'e verilir (yalnız postMessage,
   köken ve istek kimliği denetimli); kart numarasına benzeyen yazı atılır.
4. `sonuc.html` sonucu okur (`web/sonuc_coz.js`: etiketli kutu, etiket + alt
   satır, aynı satırda "Etiket: değer" veya tabloda sekmeyle ayrılmış değer;
   belirsizse okumaz) ve cariyi belirler (`web/cari_eslestir.js`):
   - Sonuç ekranında firma numarası varsa: o VKN'li giriş → **sonuc_ekrani**.
   - Yoksa sekme notu varsa: o VKN'li giriş; o cariyle **son girişten** sonra
     başka cariyle girilmediyse → **kart_sayfasi**, girildiyse seçim (0.10.1:
     not anına göre bakılmaz; eski sekmeye dönülüp yer imine yeniden dokunulunca
     not yeni olur ama sekme eskidir).
   - Hiçbiri yoksa: son 2 saatte tek cariyle girildiyse → **tek_giris**,
     birden fazlaysa seçim.
   - Seçim (**secim**): adaylar (son giriş başta) gösterilir, hiçbiri önceden
     seçili değildir; kişi seçmeden kaydedilmez.
   - Tanınmayan firma veya giriş yoksa kaydedilmez, elle kayıt istenir.
5. "Bu cariye kaydet": sonuç telefondaki **sonuç kutusuna** bırakılır
   (`web/sonuc_kutusu.js`, 2. biçim, 30 gün bekler). Ağ isteği yoktur. Kutu
   kayıtları **kimlikle** tutulur (aşağıda). Aynı kimlik kutuda başka cari veya
   tutarla bekliyorsa değiştirilmez, kişiye söylenir. Kutu denetimi Dart'taki
   kadar sıkıdır: Sanal POS'un okuyamayacağı bir sonuç "alındı" denip kabul
   edilmez.
6. Oturumu açık Sanal POS sekmesi kutuyu okur (açılışta, başka sekmede sonuç
   eklenince, sekmeye dönüşte; kilitliyse şifre girilince; bağlantı geri
   gelince ekran yeniden kurulurken), `posIslemleri`'ne yazar, sonuç sayfasına
   "Kaydedildi: …" yanıtı verir. **Sonuç kutudan yalnız sunucuda o kimlikle
   kayıt olduğu görülünce çıkar** (0.10.1). Bağlantı, oturum, yetki veya
   beklenmeyen hata: telefonda kalır, kişiye ve sonuç sayfasına söylenir, her
   açılışta yeniden denenir (ör. cari yeniden atanınca kendiliğinden yazılır).
   Aynı kimlik sunucuda başka cari veya tutarla kayıtlıysa "tamam" denmez,
   iki değer de gösterilir. Sonuç önceki gün okunup bugün yazıldıysa mesaj söyler.
   İki Sanal POS sekmesi aynı sonucu aynı anda yazarsa ikincinin reddi "zaten
   kayıtlı" sayılır (yazma reddinden sonra kayıt yeniden okunur).
7. Yer imi kullanılamazsa cari profilinde "Ödeme sonucunu elle kaydet"
   (eşleşme **elle**).
8. "Gün sonu" sekmesi: Türkiye saatiyle (UTC+3) seçilen günün kayıtları
   carilere göre; başarılı toplam, başarısız denemeler, "son girişin sonucu
   kaydedilmedi" uyarısı, seçimle bağlanan ve geç okunan işlem notları,
   yönetici "Herkes", Excel'e aktarma (CSV; `;`, virgüllü kuruş, BOM; eşleşme
   ve telefon okunma saati sütunları).

## Kayıt alanları ve kurallar (firestore.rules)

- `posGirisleri/{20 harf}`, `posIslemleri/{kimlik}`: yalnız `create`;
  `update`/`delete` kapalı. `zaman == request.time` (gün ve sıra sunucu saati).
- **Kimlik (0.10.1):** başarılı ödemede Pos Sipariş Numarası, başarısız
  denemede sonuna `-h` (numara büyük harftir, karışmaz). DenizPay başarısız
  denemeden sonraki başarılı ödemeye aynı numarayı verse de başarılı ödeme
  "zaten kayıtlı" diye yutulmaz. 0.10.0 ve öncesindeki başarısız kayıtların
  kimliği eksizdir; numara her zaman `posSiparisNo` alanından okunur. Dart
  `belgeKimligi`, JS `sonuc_kutusu.js kimlik`, kural aynıdır (ortak örnek dosyası).
- **Görünmez işaretler (0.10.1):** banka yazısındaki yön/sıfır genişlik/BOM/
  yumuşak tire işaretleri okunan değerden atılır (`sonuc_coz.js GORUNMEZ`,
  Dart `gorunmez`). 0.10.0'da sayfa bunları kabul edip Sanal POS sonucu
  sessizce siliyordu.
- Yazan kendisidir (`kullaniciId`, `kullaniciAd` kullanıcı kaydıyla aynı);
  cariye erişimi olmalı, cari silinmemiş ve **VKN/TC sunucudaki cariyle aynı**.
- Aynı kimlik ikinci kez yazılamaz. Olmayan kaydı sorgulamak serbest (çift
  kayıt denetimi için).
- `eslesme` (0.10.0, denetim izi): elle kayıtta `elle` ve `okunma` yok; yer imi
  kaydında `sonuc_ekrani`/`kart_sayfasi`/`tek_giris`/`secim` (ve 0.9.0
  sayfasından telefonda kalmış sonuç için `son_giris`). `okunma`: sonucun
  telefonda okunduğu an; yalnız bilgi, telefon saati kayık olabileceği için
  1 gün ileri / 31 gün geri sınırı. 0.9.0 belgelerinde iki alan yoktur; okurken
  `son_giris` / yok sayılır.
- Okuma: sahibi ve yönetici. Satıcı yalnız `kullaniciId == uid` süzgeciyle listeler.
- İndeksler: (`kullaniciId`, `zaman`) iki koleksiyon için.

## Gün sonu neden "otomatik"

Kayıtlar değiştirilemez/silinemez ve gün sunucu saatiyle belirlenir. Gün
00:00'da bittiğinde o güne yeni kayıt eklenemez; gün sonu her açılışta aynı
kayıtlardan aynı sonucu verir. Sunucu işlevi (Cloud Functions) yoktur — billing
kapalı kalır. Ödünleşim: sonuç Sanal POS sekmesine gece yarısından sonra
ulaşırsa ertesi güne yazılır; mesaj ve gün sonu bunu (telefon okunma saatiyle)
açıkça gösterir.

## Testler

- Dart: `test/tahsilat_test.dart` (eşleşme tutarlılığı, kodların kural/JS ile
  aynılığı, geç okunma, CSV), `test/tahsilat_servisi_test.dart`, `test/gun_sonu_test.dart`.
- Tutar ve ekran örnekleri `test/veri/tahsilat_ornekleri.json` — Dart ve JS aynı dosyayla.
- `npm run test:saf` (`tools/tarayici/sonuc-saf.mjs`, tarayıcısız): okuma
  örnekleri, cari eşleştirme, giriş listesi, sonuç kutusu biçimi.
- `tools/sunucu-test/kurallar.test.mjs` (emülatör): yalnız ekleme, VKN,
  sahiplik, okuma, eşleşme/okunma alanları.
- `npm run test:doldur` (taklit DenizPay: kutu/tablo/büyük harf düzeni, tek
  giriş, seçim, kart sayfası notu, eski sekme, sonuç ekranı firması, görünmez
  işaretler, aynı numarada başarısız + başarılı, eski yer imi, köken),
  `npm run test:tahsilat` (emülatör paketi 4197 + emülatörler: giriş → sonuç →
  kayıt → kapalı sekme → yeni sekme girişi silmez → 0.9.0'dan bekleyen sonuç →
  gün sonu → CSV → aynı numarada başarısız + başarılı → görünmez işaretler →
  internet kesik iken sonuç telefonda kalır, gelince kendiliğinden yazılır →
  iki Sanal POS sekmesi aynı anda yazar, tek kayıt ve yanlış uyarı yok).

## Açık kalanlar

- Gerçek DenizPay sonuç sayfasının HTML'i görülmedi; tanınmayan düzende sayfa
  "elle kaydet" der. İlk gerçek ödemede denenmeli.
- ☰ menüsünde/sonuç ekranında firma VKN'si varsa kesin eşleşme kendiliğinden devrede.
- Kayıt düzeltme/iptal yok ve olmayacak (kullanıcı kararı, 23 Ekim: hata
  sonradan düzeltilmez, baştan önlenir).
- Aynı kimlikte (numara + sonuç) farklı tutarla ikinci sonuç gelirse yazılamaz;
  kişiye iki değer gösterilir, yöneticiye bildirilir (DenizPay'in böyle bir
  davranışı görülmedi).
- Sonuç kutusu en çok 20 bekleyen sonuç tutar.
- 0.10.0 ve öncesinde yazılmış bir başarısız kaydın numarasıyla (kimliği "-h"
  eksiz) başarılı ödeme gelirse yazılamaz; "Dikkat … Okunan sonuç farklı"
  uyarısı çıkar. 0.10.1 yayınlandığında gerçek ödeme henüz alınmamıştı.
- Safari, 7 gün açılmayan sitenin cihaz deposunu silebilir: cihazdaki tam kart
  gider (tahsilat sunucuda). `navigator.storage.persist()` istenir; garanti değil.
