# Tahsilat kaydı ve gün sonu (0.9.0)

Kullanıcı isteği (22 Ekim 2026): bir cariyle DenizPay'e girilip alınan ödeme
kesin olarak o cariye yazılsın; 24 saatteki bütün işlemler tarih, saat ve cari
adıyla kaydedilsin; gün bitince gün sonu kendiliğinden oluşsun.

## Bilinen gerçekler

- DenizPay'e hangi carinin VKN/TC'siyle girildiyse tahsilat LED'de o cariye
  kendiliğinden eklenir (kullanıcı). Doğru cari = DenizPay'e doğru cariyle girmek.
- Sonuç ekranı (kullanıcı görüntüleri): başarılıda **Onay Formu** — Açıklama
  ("Ödeme Başarıyla Gerçekleştirildi"), Üye Sipariş Numarası, Pos Sipariş
  Numarası ("VP…"), Tutar. Başarısızda **Hata Formu** — Açıklama ("3D Şifresi
  Yanlış."), Pos Sipariş Numarası, Tutar. Tutar biçimi değişken: "4500",
  "45678,90". Sayfa HTML'i görülmedi; okuma etiket metnine dayanır.
- Sanal POS oturumu yalnız açık olduğu sekmededir (`Persistence.SESSION`,
  güvenlik kararı). DenizPay'den açılan sekme sunucuya yazamaz.

## Akış

1. "DenizPay'e giriş yap": DenizPay açılmadan önce bu cihaza **son giriş
   işareti** yazılır (`web/acik_giris.js`, 2 saat: cari id/ad/VKN, kartın son
   dört hanesi, giriş kimliği). Sunucuya `posGirisleri` kaydı gider.
2. DenizPay sonuç ekranında "BUP Doldur" (yer imi 2. sürüm) sayfadaki etiketli
   kutuların yazısını `sonuc.html`'e verir; kart numarasına benzeyen yazı atılır.
3. `sonuc.html` sonucu okur (`web/sonuc_coz.js`), son giriş işaretinin carisini
   gösterir; sayfada firma VKN'si varsa ve farklıysa reddeder. Kişi **"Bu
   cariye kaydet"**e basınca sonuç telefondaki **sonuç kutusuna** bırakılır
   (`web/sonuc_kutusu.js`). Ağ isteği yoktur.
4. Oturumu açık Sanal POS sekmesi kutuyu okur (açılışta, başka sekmede sonuç
   eklenince, sekmeye dönüşte), `posIslemleri`'ne yazar, kutudan siler ve
   sonuç sayfasına/DenizPay kutusuna "Kaydedildi: …" yanıtı verir. Sekme
   kapalıysa kayıt yeniden girişte yapılır. Bağlantı yoksa kutuda kalır.
5. Yer imi kullanılamazsa cari profilinde "Ödeme sonucunu elle kaydet".
6. "Gün sonu" sekmesi: Türkiye saatiyle (UTC+3) seçilen günün kayıtları
   carilere göre; başarılı toplam, başarısız denemeler, "son girişin sonucu
   kaydedilmedi" uyarısı, Excel'e aktarma (CSV; `;`, virgüllü kuruş, BOM).
   Yönetici "Herkes" ile tüm kullanıcıları görür.

## Kurallar (firestore.rules)

- `posGirisleri/{20 harf}`, `posIslemleri/{Pos Sipariş No}`: yalnız `create`;
  `update`/`delete` kapalı. `zaman == request.time`.
- Yazan kendisidir (`kullaniciId`, `kullaniciAd` kullanıcı kaydıyla aynı);
  cariye erişimi olmalı, cari silinmemiş ve **VKN/TC sunucudaki cariyle aynı**.
- Belge kimliği Pos Sipariş Numarası: aynı ödeme ikinci kez yazılamaz.
  Olmayan numarayı sorgulamak serbest (çift kayıt denetimi için).
- Okuma: sahibi ve yönetici. Satıcı yalnız `kullaniciId == uid` süzgeciyle listeler.
- İndeksler: (`kullaniciId`, `zaman`) iki koleksiyon için.

## Gün sonu neden "otomatik"

Kayıtlar değiştirilemez/silinemez ve gün sunucu saatiyle belirlenir. Gün
00:00'da bittiğinde o güne yeni kayıt eklenemez; gün sonu her açılışta aynı
kayıtlardan aynı sonucu verir. Sunucu işlevi (Cloud Functions) yoktur — billing
kapalı kalır. Ödünleşim: sonuç Sanal POS sekmesine gece yarısından sonra
ulaşırsa (sekme kapalıydı) ertesi güne yazılır; kayıt `zaman`ı sunucu saatidir.

## Testler

- `test/tahsilat_test.dart`, `test/tahsilat_servisi_test.dart`, `test/gun_sonu_test.dart`.
- Tutar ve ekran örnekleri `test/veri/tahsilat_ornekleri.json` — Dart ve JS aynı dosyayla.
- `tools/sunucu-test/kurallar.test.mjs` (emülatör): yalnız ekleme, VKN, sahiplik, okuma.
- `npm run test:doldur` (taklit sonuç ekranları, köken ve kutu), `npm run test:tahsilat`
  (emülatör paketi 4197 + emülatörler: giriş → sonuç → kayıt → kapalı sekme → gün sonu → CSV).

## Açık kalanlar

- Gerçek DenizPay sonuç sayfasının HTML'i görülmedi; etiketler farklıysa sonuç
  sayfası "elle kaydet" der. İlk gerçek ödemede denenmeli.
- ☰ menüsünde firma VKN'si varsa ek karşılaştırma kendiliğinden devrede.
- Kayıt düzeltme/iptal yok (bilinçli: değiştirilemez kayıt).
