# Arayüz ve kullanım taraması — 22 Ekim 2026 (0.8.0)

Kullanıcı isteği: "Arayüzle ilgili kullanıcı deneyimini etkileyen sorunları bul,
raporla; sonra rapora göre ilerleyeceğiz."

**0.8.1'de yapıldı:** 1 (✕ düğmesi yerine üstte boşluk — kullanıcı kararı), 2, 3,
4, 11, 16; 15 kısmen ("Cariyi sil" yazılı ve kırmızı). Kalanlar bekliyor.

Nasıl tarandı: bütün ekran kodu okundu; emülatör paketi (yapay hesaplar) üç
boyutta gezilip ekran görüntüsü alındı: 390×844 (yeni iPhone), 375×548
(iPhone SE 2020'nin Safari'de görünen alanı), 320×640 (en dar telefon).
Görüntüler `/tmp/bup-ux/` altında (depoya girmez). Gerçek telefonda denenmedi.

Kullanıcının bildirimi (iPhone SE 2020): kart ekleme penceresi ekranın en
üstüne kadar çıkıyor; kapatmak için üstteki çizgiden aşağı çekmek gerekiyor,
o çizgi ekranın tepesinde kalıyor.

## A. Önce düzeltilmesi gerekenler (her gün işi zorlaştırıyor)

1. **Alttan açılan pencerelerde kapatma düğmesi yok.** Kart ekle/düzenle,
   Yeni cari/Cariyi düzenle ve Ödeme sitesine geç pencereleri ekran boyu açılıyor;
   kapatmak için yalnız tepedeki çizgi var, "Vazgeç" ise formun en altında.
   SE'de çizgiye ulaşılamıyor (kullanıcı bildirimi). Öneri: her pencerenin
   başlık satırına sağda büyük bir ✕ (Kapat) düğmesi; pencere ekranın tamamını
   değil üstte boşluk bırakarak açılsın.
2. **Hata yazıları düzeltince kaybolmuyor.** Kart formunda "Kartı kaydet"e boş
   basınca çıkan kırmızı uyarılar, alanlar doğru doldurulduktan sonra da
   kalıyor ("Karta en az 2 karakterlik bir ad ver" yazısı adın altında duruyor).
   Kişi hâlâ yanlış bir şey var sanıyor. Aynı durum Yeni cari ve Giriş
   ekranında da var. Öneri: yazdıkça uyarı kendiliğinden kalksın.
3. **Küçük ekranda cari listesi görünmüyor.** SE'de açılış ekranının tamamını
   "Cariyi bul, kartını seç." başlığı, koyu sayı kutusu (Cari/Kart özeti),
   arama ve süzgeçler kaplıyor; tek bir cari bile görünmüyor. Öneri: büyük
   başlığı ve koyu kutuyu kaldır/küçült, arama en üstte, cariler hemen altında.
4. **Cari profilinde kartlar ekranın altında kalıyor.** Profil açılınca önce
   VKN/TC kopyala, POS şifresini kopyala, açıklama, Yıldızla, Düzenle, Sil,
   Kullanıcıya ata geliyor; asıl iş olan kart seçimi SE'de ikinci ekranda.
   Öneri: kartlar en üstte; seyrek kullanılan düğmeler bir "Diğer işlemler" (⋮)
   menüsünde ya da kartların altında.
5. **DenizPay'e gitmek 4 dokunuş ve bir onay kutusu istiyor.** Kart seç →
   "Ödeme sitesine geç" → "Cari ve seçili kartı kontrol ettim" kutusu →
   "Seçimi kontrol et" → "DenizPay'e giriş yap". Aradaki onay kutusu ve kontrol
   adımı her ödemede tekrar ediyor; düğme adları da her adımda değişiyor.
   Öneri: pencere açılır açılmaz kontrol kendiliğinden yapılsın, kutu
   kalksın; kişi cari/kart özetini görüp doğrudan "DenizPay'e giriş yap"a bassın
   (2 dokunuş). Güvenlik kontrolü aynen kalır, yalnız beklemeden yapılır.

## B. Kolaylaştırma (orta öncelik)

6. **Kart formu kalabalık.** Her alanın altında "0/60, 0/23, 0/120, 0/24"
   sayaçları; üstte uzun açıklama kutusu. Kart adı zorunlu, kişi ad uydurmak
   zorunda. Öneri: sayaçları kaldır; kart adı boş kalırsa "Kart •••• 1234"
   otomatik verilsin; açıklama tek satıra insin.
7. **Kart numarası okunaksız.** 16 hane bitişik yazılıyor (4111111111111111);
   kontrol etmek zor. Öneri: dörtlü gruplar halinde gösterim (4111 1111 1111 1111).
8. **Ödeme penceresi sonucunda iki ana düğme yarışıyor.** "DenizPay'e giriş yap"
   ve "Kartlara dön" aynı renkte/ağırlıkta. Başlıkta yeşil "tamam" simgesi var
   ama henüz bir şey olmadı. Öneri: "Kartlara dön" sade yazı düğmesi; simge kalksın.
9. **Üst çubuk küçük ekranda yer kaplıyor.** Üst çubuk 72, alt sekme çubuğu 76
   nokta; SE'de ekranın dörtte biri. "0.8.0" sürüm etiketi düğme gibi görünüyor
   ama bir işe yaramıyor. Öneri: çubukları inceltmek, sürümü yalnız Çalışma
   alanında göstermek.
10. **Çalışma alanı sayfası yazı yüklü ve eskimiş bilgi içeriyor.** "Yayınlandıktan
    sonra… Ana Ekrana Ekle" (zaten yayında); uzun POS bağlantısı paragrafı;
    "Ekranı kilitle" üst çubukta zaten var. "BUP Doldur yer imini kur" (yeni
    telefonda en gerekli düğme) aşağıda kalmış. Öneri: kısa metin, önce
    "BUP Doldur yer imini kur", sonra hesap düğmeleri.
11. **Boş liste yazısı yanlış.** Canlı hesapta da "Yeni cari düğmesiyle bir
    deneme kaydı oluşturabilirsin" yazıyor (gerçek kayıt oluşur). Düzeltilecek.
12. **Açılış bağlantı hatasında düğme yok.** İnternet yoksa "Bağlantı kurulamadı.
    Sayfayı yenileyip tekrar deneyin." yazıyor ama "Yeniden dene" düğmesi yok;
    telefonda sayfa yenilemek zor. Öneri: düğme eklensin.
13. **Şifre değiştirme sayfası.** Şifreyi göster düğmesi yok; boş "Mevcut şifre"
    ile gönderilebiliyor; hata tek genel cümle. Öneri: göz düğmesi ve alan
    başına açık uyarı.

## C. Küçük ayrıntılar

14. Silme onaylarında "Sil / Cariyi sil" düğmesi sıradan renkte; kırmızı olmalı.
15. Cari profilindeki çöp kutusu düğmesinin yazısı yok; 320'de tek başına alt
    satıra düşüyor.
16. Süzgeç düğmeleri (Tümü / Yıldızlılar / Kartı olanlar) SE'de iki satıra bölünüyor.
17. Üstte çıkan bilgi notları (ör. kart kaydı uyarısı) kapatılamıyor; bir sonraki
    işleme kadar duruyor.
18. Yönetim ekranındaki "Hesap aç" düğmesi uygulamanın renginde değil (açık
    camgöbeği); Yeni hesap formunda da sayaçlar var.

## Bilinçli olarak dokunulmayacaklar

- Kilitten sonra cari listesine dönülmesi (güvenlik kararı).
- Kartın kendiliğinden seçilmemesi (önceki karar).
- CVV'nin hiçbir yerde istenmemesi/saklanmaması.

## Önerilen sıra

İlk paket: 1, 2, 3, 4, 11 (küçük ekran ve kapatma sorunu; düşük risk).
İkinci paket: 5 (DenizPay'e geçiş adımları — kullanıcı onayı gerekir).
Sonra: 6–10, 12–13, en son C bölümü.
