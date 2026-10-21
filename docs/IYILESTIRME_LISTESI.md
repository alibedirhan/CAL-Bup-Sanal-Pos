# İyileştirme listesi — 21 Ekim 2026 (0.7.2 sonrası)

Durum: iPhone Safari'de otomatik giriş + "BUP Doldur" kart doldurma kullanıcıca
doğrulandı. Bu liste kullanıcının "geliştirmemiz gerekenleri tespit et" isteğiyle
çıkarıldı; hiçbiri henüz uygulanmadı. Öncelik sırası öneridir, karar kullanıcıda.

## 21 Ekim gece yapılanlar (0.7.3)

Kullanıcı 1, 2, 4, 6, 7, 8'i seçti (eski numaralarla: Actions, API anahtarı,
şifre sorma, Kartı Tara, yer imi sürümü, temizlik) + "takılmadan kasmadan".
- Actions: `.github/workflows/kontrol.yml` (biçim, analiz, Dart, demo derleme,
  demo/kasa/doldur tarayıcı testleri; gizli anahtar yok, yayın yok).
- API anahtarı: denendi — kısıtlı DEĞİL (başka referrer'dan 200). Değişiklik
  kullanıcının Google Cloud hesabında; adımlar kullanıcıya verildi. Bilgisayardaki
  `gcloud` başka projenin (ciftlik-ajandasi) hizmet hesabına bağlı; kullanılmadı.
- Şifre sorma: DenizPay'den 5 dk içinde dönüşte kilit yok (`donusSuresi`).
- Kartı Tara: kullanıcı denemesi bekleniyor. 0.8.0'da "Karttan oku" kutusu ve
  tarama sonrası tarih/yıl düzeltmeleri eklendi (22 Ekim).
- Yer imi sürümü: `doldur_sayfasi.js` `EN_AZ_YER_IMI`; yer imi `&s=` gönderir,
  numarasız (kurulu olan) = 1, yeniden kurulum gerekmez.
- Temizlik: deneme sayfası/yer imi/testi ve `otomatik-giris` dalı kaldırıldı.
- Hız: Firebase SDK ve yerel modüller paralel yüklenir; `main.dart.js` ön
  yüklenir; gstatic/firestore'a önceden bağlantı. Önbellek önceki kayıtta.

## Önemli

1. ~~**Cariye özel DenizPay kullanıcı adı/şifresi.**~~ *Reddedildi (21 Ekim): kullanıcı
   cariyi ve VKN/TC'yi kendisi ekliyor, DenizPay girişi için VKN/TC yeterli;
   "DenizPay tarafında bir şey yapma". Yapılmayacak.*
   Eski öneri: Şu an her cari için kullanıcı
   adı = VKN/TC, şifre = ilk 2 + son 2 hane. CAL bup saha testinde (7 Ekim) ikinci
   cari bu kuralla reddedilmişti (POS'ta VKN yerine TC kayıtlıydı); CAL bup bunun
   için cariye özel giriş alanı ekledi. Sanal POS'ta yok: kural tutmayan caride
   otomatik giriş olmaz, BUP Doldur da firma numarası uyuşmadığı için yazmaz.
   Öneri: cari formunda isteğe bağlı "DenizPay kullanıcı adı/şifre"; şifre yalnız
   cihaz kasasında şifreli (kart gibi), firma eşleşmesi DenizPay'deki numarayla.
2. **Android denemesi.** *Ertelendi (21 Ekim, kullanıcı: "şimdilik kalsın").* Hiç yapılmadı. Chrome'da yer imi adres çubuğuna adı
   yazılarak çalıştırılır; ana ekran simgesi `display: browser` ile Chrome sekmesi.
3. **Otomatik testlerin GitHub'da çalışması (Actions).** Dart testleri ve
   analiz her gönderimde kendiliğinden koşsun; tarayıcı testleri sonra eklenebilir.
4. **Firebase web API anahtarının kısıtlanması.** Google Cloud konsolunda
   anahtarın yalnız `bup-sanal-pos-izmir.web.app` / `firebaseapp.com` için
   çalışacak şekilde kısıtlı olduğu doğrulanmalı (bu oturumda bakılmadı).

## Kullanım kolaylığı

5. **"Bu kartı doldur" düğmesi.** Aynı caride başka karta geçmek için şimdi
   "DenizPay’e giriş yap" yeniden gerekiyor (yeni sekme). Giriş yapmadan yalnız
   bekleyen kartı değiştiren düğme.
6. **Sekme değişince şifre sorma.** DenizPay'e geçmek Sanal POS'u kilitliyor;
   dönüşte hesap şifresi isteniyor. Kısa bir dönüş süresi (ör. 2 dk) güvenlik
   ödünleşimiyle düşünülebilir; kullanıcıya sorulmalı.
7. **Kart üzerindeki ad hatırlatması.** Boşsa DenizPay "Ad Soyad" boş kalıyor;
   kart formunda kısa not.
8. **Fotoğraftan kart okuma.** Kart formu iPhone "Kartı Tara" için hazır
   (0.5.1) ama gerçek cihazda denenmedi. Uygulama içi okuyucu (Aşama 3/2) yok.
9. **Yer imi sürüm uyarısı.** Yer imi kodu ileride değişirse telefondaki eski
   kurulumu fark edip "yeniden kur" diyen kontrol (yer imi sürümünü doldur
   sayfasına iletmeli).

## Bakım

10. **Eski belgeler/dosyalar.** `docs/POS_KARARI.md` 0.4.1'de kalmış; deneme
    sayfası (`deneme.html`) ve yerel `otomatik-giris` dalı temizlenebilir.
11. **DenizPay sayfası değişirse.** Doldurma güvenli şekilde durur ("kart kutuları
    bulunamadı"), yanlış kutuya yazmaz; izleme yok, kullanıcı bildirince güncellenir.

## Bizim çözemeyeceklerimiz (bilinçli riskler)

- DenizPay şifre kuralı (VKN'nin ilk 2 + son 2 hanesi) zayıf; numarayı bilen
  girer. Kullanıcı kararı: DenizPay tarafına hiçbir şey yapılmaz/önerilmez.
- Kart numaraları telefonda şifreli tutulur; PCI uyumluluk iddiası yoktur.
- Dokunmasız (otomatik) doldurma tarayıcıda mümkün değil; App Store uygulaması
  veya Safari eklentisi ücretli Apple hesabı gerektirir (kullanıcı istemedi).
