# Route Çizgisi — fikir ve plan dosyası

> **Durum (17 Kasım 2026): Aşama 1 başladı** (Ali: "güvenli, sağlam temelli yapalım"). Teknik
> mimari `ROTA_MIMARI.md`; kalan açık sorular Aşama 1'i engellemiyor. 17 Kasım'da depo
> adresi, harita izleyicileri ve bölge dışı alarmı kararlaştırıldı (K25–K27, K6 güncellendi). Bu dosya konuşmaları toplamak,
> karar ve açık soruları bir arada tutmak içindir. Uygulamaya geçme kararı Ali'nindir.

## 1. İstek

Yöneticinin isteği: plasiyerlerin gün içinde **nerelere gittiği, hangi yolu izlediği, şu an
nerede olduğu, nerede ne kadar durduğu, ne kadar süre ve kaç km yol yaptığı** harita üzerinde
bir "route çizgisi" olarak görülsün. Amaç izleme, analiz, rotaları iyileştirme ve **yakıt
tasarrufu**.

Fikir: Sanal POS Android uygulaması zaten el terminallerinde (Zebra TC15) kurulu ve
kullanılıyor; GPS bilgisi bu uygulama içinden toplanır. Harita **CAL_bup**
(https://cal-bup-ali.web.app/CAL_bup/) içinde, canlı olarak görülür.

## 2. Alınmış kararlar (Ali, 16 Kasım 2026)

| # | Karar |
|---|-------|
| K1 | **KVKK tamam:** şirket onayladı, plasiyerler de onay verdi. (Aydınlatma metni ve onay belgeleri şirkette; yazılım tarafında ayrıca onay ekranı istenmedi.) |
| K2 | **Plasiyerin elinde düğme yok.** "Güne başla / Günü bitir" olmayacak. Takibin açılıp kapanması merkezden (CAL_bup) yapılır. |
| K3 | **24 saat takip.** Bazı rotalar 24 saat sürüyor; konum, takip açık olduğu sürece gece gündüz arka planda alınır. Rota "takvim günü" ile değil, açılış–kapanış aralığıyla tanımlanır. |
| K4 | **Terminaldeki uygulama yalnız GPS toplar.** Mevcut Sanal POS kullanımı aynen sürer; konum işi arka planda sessizce çalışır. |
| K5 | **Bir terminali birden çok plasiyer kullanabilir.** Hangi terminalin hangi saatte hangi plasiyerde olduğunu merkez belirler (bkz. §4 "Terminal–plasiyer ataması"). |
| K6 | **Bölge: İzmir + Aydın + Manisa** (17 Kasım 2026: plasiyerler artık Manisa'ya da gidiyor). Harita bu üç ille sınırlı açılır. |
| K7 | İşi profesyonel bir ekiple yapacağız; bu dosya ekibin de okuyacağı şekilde yazıldı. |
| K9 | **6 plasiyer, 6 terminal** (her plasiyerde terminal var). |
| K10 | Harita merkezden izlenir; CAL_bup'ta **"Rota" adında ayrı bir sekme**. |
| K11 | **Her plasiyerin kendi rengi** var; bir renk/plasiyer seçilince yalnız o öne çıkar. |
| K12 | **Sokak düzeyinde yakınlaştırma** şart: dar sokaklardaki müşterinin tam konumu görülebilmeli. |
| K13 | Seçilen plasiyer için **ortalama hız, günlük km, harcanan yakıt**; bu bilgiler **gün gün saklanır**. |
| K14 | **Saklama süresi 3 ay** (ham konum ve günlük özetler); süresi dolan kayıt kendiliğinden silinir. |
| K15 | KVKK yükümlülükleri yerine getirildi, plasiyerlere imzalatıldı (16 Kasım 2026, Ali). |
| K16 | **6 terminalin hepsi Zebra TC15.** |
| K17 | **Terminal kaydı kurulumda bir kez yapılır:** Ali uygulamayı yüklerken listeden araç seçer (ör. "Araç 01 – Ahmet ALTILI"); terminal o araç olarak kaydolur. Plasiyerden giriş/seçim istenmez. Terminal başka plasiyere geçerse merkezden (CAL_bup) değiştirilir (K5). LED programındaki "Araç 1 + parola" girişi ayrıdır, ona dokunulmaz. |
| K18 | **Müşteri adresleri henüz yok, oluşturuluyor.** Hazır olunca içe aktarılır (§4.4). |
| K19 | **Şimdilik terminaller Sanal POS'a Ali'nin hesabıyla otomatik giriyor**; ileride kaldırılacak. Konum işi buna bağlanmaz (§7 "Hesap"). |
| K20 | **Plasiyer suistimali endişesi:** takibin terminalde göze batmaması ve kapatılamaması istendi (§4.1b). |
| K21 | **Amaç şirket varlığını korumak:** araç ve taşınan mal plasiyere zimmetli; olumsuz bir durumda **erken müdahale** gerekiyor (§4.7). Terminal de şirketçe zimmetli; plasiyer araçta izleme olduğunu biliyor. |
| K22 | **Bazı plasiyerler iş bitince terminali depoya bırakır.** Terminal depodayken rota bitmiş sayılır; depo süresi rota/km/yakıt hesabına girmez (§4.2b). |
| K23 | **Araçlarda araç takip sistemi var, ama maliyeti yüksek;** terminal tabanlı takip bu maliyeti azaltmak için düşünülüyor. Plasiyerlerin nasıl kötüye kullanabileceği henüz bilinmiyor; bu yüzden bildirimin görünmemesi tercih edildi (§4.1c). |
| K24 | **Plasiyer hiçbir şey görmez.** Bütün uyarılar, rota, km, özet yalnız merkezde (CAL_bup Rota sekmesi). Terminalde uyarı, mesaj, ekran, ses yok. Tek istisna Android'in zorunlu bildirimi; o da bildirim izni kapatılarak çubuktan gizlenir (§4.1b). |
| K25 | **Depo:** İzmir Bupiliç Şube Müdürlüğü — Egemenlik Mah., 6106/4 Sk. No:17 D:C, 35060 Bornova/İzmir (17 Kasım 2026). Depo bölgesi (§4.2b) bu adresin çevresinde çizilir; tam koordinat Aşama 3'te haritada Ali'nin işaretlemesi/onayıyla alınır. |
| K26 | **Haritayı şimdilik Ali ve yönetim ekibi görür;** daha sonra genişletilebilir (17 Kasım 2026). Yönetim ekibine CAL_bup Rota sekmesi için erişim açılacak (§4.3, §8 soru 3b). |
| K27 | **Bölge dışı alarmı:** terminal İzmir, Aydın ve Manisa dışına çıkınca merkeze **basit, bildirim tarzında bir alarm** (17 Kasım 2026). Plasiyer görmez (K24). |
| K28 | **Alarm önce yalnız CAL_bup açıkken:** sayfa içi uyarı + tarayıcı bildirimi; CAL_bup kapalıyken telefona bildirim sonra (17 Kasım 2026, Ali önerileri kabul etti). |
| K29 | **Terminal kaydı merkezde onaylanır** (K17'nin inceltmesi, 17 Kasım 2026; Ali "sana güveniyorum" dedi): terminal kendiliğinden bir başvuru bırakır, Ali CAL_bup'ta onaylar ve aracı orada seçer. Terminal ekranında araç listesi yok. Rota yetkisi yalnız Google girişli hesaplarda; terminaldeki Ali oturumu rota verisine dokunamaz. Teknik ayrıntı `ROTA_MIMARI.md`. |
| K8 | Harita **CAL_bup** içinde olacak. Not: Sanal POS bugüne kadar CAL_bup'tan bağımsızdı; bu özellik ikisi arasında **yalnız okuma** yönünde bir bağ kurar (CAL_bup, Sanal POS'un konum kayıtlarını okur ve takip ayarını yazar). |

## 3. Genel yapı

```
┌────────────────────────────┐
│ Zebra TC15 — Sanal POS     │  arka plan konum hizmeti (24 saat)
│  • GPS noktası: 15–30 sn   │  • internet yoksa noktalar cihazda birikir
│  • toplu gönderim: 1–2 dk  │  • merkezden gelen ayarı dinler (aç/kapa, sıklık)
└─────────────┬──────────────┘
              │ yazar                         ▲ ayarı okur
              ▼                               │
┌────────────────────────────────────────────────────────┐
│ Firebase — "BUP Sanal POS" projesi (Firestore)         │
│  cihazlar/{cihazId}            takip açık mı, sıklık   │
│  atamalar/{id}                 terminal → plasiyer     │
│  konumlar/{cihazId}/parcalar   nokta paketleri         │
│  sonDurum/{cihazId}            canlı harita için       │
└─────────────┬──────────────────────────────────────────┘
              │ canlı dinleme (okur) + ayar yazma (yönetici)
              ▼
┌────────────────────────────────────────────────────────┐
│ CAL_bup → yeni "Rotalar" sayfası                       │
│  canlı harita · rota çizgisi · duraklar · km · süre    │
│  terminal aç/kapa · terminal–plasiyer ataması · analiz │
└────────────────────────────────────────────────────────┘
```

Neden böyle: Sanal POS zaten Firebase'e yazıyor (giriş, cariler, tahsilatlar); konum aynı
projeye eklenir. CAL_bup ikinci bir Firebase bağlantısıyla (yalnız yönetici hesabıyla) bu
kayıtları okur.

## 4. Parçalar

### 4.1 Terminalde konum toplama (Sanal POS Android)

- **Ön plan konum hizmeti (foreground service):** Android'in arka planda konumu kesintisiz
  almanın tek güvenilir yolu. Uygulama kapatılsa, ekran kilitlense de çalışır; cihaz yeniden
  başlarsa kendiliğinden açılır.
- **Android'in zorunlu bildirimi:** Android 8+ bu hizmet çalışırken bildirim çubuğunda **küçük,
  sessiz, kalıcı bir bildirim** gösterilmesini işletim sistemi düzeyinde şart koşar; uygulama
  bunu kapatamaz. İçeriği sade olur (ör. "BUP Sanal POS çalışıyor"); plasiyere düğme veya seçenek
  sunmaz. Android 13+'ta kullanıcı bu bildirimi kaydırıp gizleyebilir, hizmet yine çalışır.
- **İzinler:** "Her zaman konum" (arka plan konumu) ve pil iyileştirmesinden muafiyet. Zebra'da
  bu izinler **cihaz yönetimiyle (Zebra StageNow / MX ya da şirketin MDM'i)** önceden verilebilir,
  böylece plasiyerden hiçbir şey istenmez. Hangi MDM'in kullanıldığı soruldu (§8).
  - _MDM nedir:_ "Mobil Cihaz Yönetimi". Şirketin bilgi işlemi terminallere uzaktan uygulama
    kurmak, izin vermek, ayar kilitlemek için bir yönetim programı kullanıyor olabilir (SOTI,
    Intune, Zebra StageNow vb.). Varsa konum izni oradan 6 terminale birden verilir. Yoksa her
    terminalde **bir kez** elle "Her zaman izin ver" seçilir; sonrası kendiliğinden çalışır.
    Bilgi işleme sorulacak.
- **Akıllı sıklık (pil için):** araç hareket ederken 15–30 sn'de bir nokta; uzun süre
  durduğunda seyrekleşir (ör. 2–5 dk). Böylece 24 saatlik takipte pil ve veri dayanır.
- **İnternetsiz çalışma:** kapsama dışı yerlerde noktalar cihazda birikir, bağlantı gelince
  sırayla gönderilir. Rota çizgisinde boşluk kalmaz, yalnız canlı konum gecikir.
- **Merkezden kumanda:** uygulama `cihazlar/{cihazId}` belgesini dinler: takip açık/kapalı,
  nokta sıklığı. CAL_bup'tan "kapat" denince birkaç saniye içinde durur.
- **Her noktada:** zaman, enlem/boylam, doğruluk (m), hız, yön; isteğe bağlı pil yüzdesi
  (terminalin şarjı bitmek üzere uyarısı için).

### 4.1b Bildirim ve suistimale karşı önlem (K20)

**Bildirim:** Android sürekli arka plan konumu için bildirimi şart koşar; tamamen yok edilemez.
Android 13 ve sonrasında uygulamanın **bildirim izni verilmezse** bu bildirim bildirim
çubuğunda görünmez; uygulama yalnız hızlı ayarlar altındaki "etkin uygulamalar" listesinde
durur. TC15'in Android sürümü kontrol edilmeli (§8). Bildirim izni kapalı kalırsa Sanal
POS'un başka bildirimi de görünmez (şu an bildirim kullanmıyor).

**Asıl önlem gizlemek değil, kapatılamaz yapmak ve kapatılırsa merkezin bilmesi:**
1. **Kilitleme (Zebra StageNow — Zebra'nın ücretsiz aracı, MDM gerekmez):** uygulamanın
   kaldırılması, "zorla durdur", konum izninin geri alınması ve konumun kapatılması engellenir;
   pil iyileştirmesinden muaf tutulur. Kurulumda bir kez barkod okutularak yapılır.
   (Zebra emanet cihaz — uygulamadan önce Ali'ye sorulur.)
2. **Kurcalama tespiti ve uyarı:** uygulama şunları kaydeder ve merkeze bildirir: konum
   kapatıldı/açıldı, izin geri alındı, uçak kipi, cihaz kapandı/açıldı, pil bitti, uzun süre
   veri gelmedi. Rota sekmesinde kırmızı uyarı + günlük özette "kayıp süre". Rotadaki boşluk
   açıklamasız kalmaz.
3. **Sahte konum (mock location) tespiti:** Android, konumun sahte uygulamadan gelip
   gelmediğini bildirir; böyle noktalar işaretlenir ve uyarı verilir.
4. Takibi açma/kapama ve araç seçimi **yalnız CAL_bup'ta**; Sanal POS ekranında hiç yok.

### 4.1c Kötüye kullanım yolları ve karşılıkları (K23)

Terminal araca bağlı bir cihaz değil, elde taşınan bir cihazdır. Araç takip cihazından farkı
budur; aşağıdaki tablo bu farkın risklerini ve karşılığını gösterir.

| Plasiyer ne yapabilir | Engellenir mi | Fark edilir mi |
|-----------------------|---------------|----------------|
| Konumu kapatmak, uçak kipi, izni geri almak | StageNow ile büyük ölçüde engellenir | Evet, anında uyarı |
| Uygulamayı durdurmak/kaldırmak | StageNow ile engellenir | Evet (veri kesildi) |
| Sahte konum uygulaması | StageNow ile yükleme engellenir | Evet, Android işaretler |
| Terminali kapatmak / şarjı bitirmek | Tam engellenemez | Evet (kapanış ve pil kaydı, veri kesildi) |
| GPS'i kapatmak için terminali metal kutuya koymak vb. | Engellenemez | Evet (doğruluk düşer / veri kesilir) |
| **Terminali araçtan ayırmak** (evde/başka araçta bırakıp araçla başka yere gitmek) | **Engellenemez** | **Kısmen** — aşağıya bak |

**Terminal araçtan ayrılırsa:** asıl açık risk bu. Fark etme yolları:
- Tahsilat ve LED satış/irsaliye işlemleri terminalden yapılıyorsa, terminal müşteride
  olmak zorundadır. İşlem anındaki konum müşterinin konumundan uzaksa uyarı.
- Gün boyu hiç hareket etmeyen ya da depo/ev dışında anlamsız duran terminal → uyarı.
- Müşteri ziyaret sayısının alışılmış düzenden sapması.

**Öneri — geçiş dönemi:** araç takip sistemi kaldırılmadan önce **birkaç hafta iki sistem
birlikte** çalışsın. Aynı günlerin rotaları, km'leri ve duruşları karşılaştırılır; terminalin
ne kadar tuttuğu ve plasiyerlerin terminali araçtan ayırıp ayırmadığı ölçülerek görülür.
Karar (araç takibini kaldırmak, azaltmak ya da bazı araçlarda tutmak) bu ölçüme göre verilir.

### 4.2 Terminal kimliği ve terminal–plasiyer ataması

**Kurulum akışı (K17):** Uygulama ilk kurulduğunda (veya yönetici "terminali kaydet" dediğinde)
yönetici girişiyle bir **araç listesi** açılır: "Araç 01 – Ahmet ALTILI", "Araç 02 – …".
Seçim yapılınca terminal kalıcı olarak o araca bağlanır ve konum toplamaya hazır olur.
Araç listesi (araç no, plasiyer adı, renk, tüketim) CAL_bup'ta merkezden yönetilir.
Kayıttan sonra terminal ekranında konumla ilgili hiçbir şey görünmez (yalnız Android'in
zorunlu küçük bildirimi, §4.1).

- Konum **cihaza** bağlı kaydedilir (her terminalin sabit bir kimliği olur; CAL_bup'ta
  okunur bir ad verilir: "Terminal 3 – Bornova aracı" gibi).
- Plasiyer bilgisi ayrı bir **atama defterinden** gelir: "Terminal 3, 16 Kasım 08:00'den
  itibaren Mehmet'te". Yeni atama girildiğinde öncekinin süresi o anda biter.
- Böylece aynı terminal gün içinde el değiştirse de rota doğru plasiyere bölünür; geriye dönük
  düzeltme de yapılabilir (yanlış atama girildiyse sonradan düzeltilir, konum kaydı bozulmaz).
- Araç (plaka) da aynı mantıkla atanabilir; yakıt analizi için gerekli olabilir (§4.6).

### 4.2b Depo bölgesi (K22)

- Deponun konumu ve çevresinde bir **depo bölgesi** (ör. 100–150 m yarıçap) tanımlanır.
- Terminal depo bölgesine girip orada kalırsa durumu **"Depoda"** olur: rota o anda kapanır,
  nokta sıklığı en aza iner (pil), depoda geçen süre km/hız/yakıt hesabına girmez.
- Depodan çıkınca yeni rota kendiliğinden başlar. Böylece 24 saatlik rotalar da, terminali
  her akşam depoya bırakanlar da aynı mantıkla doğru bölünür.
- Haritada depodaki terminaller tek bir "Depo" simgesinde toplanır.
- Not: terminal depodayken aracın kendisi izlenmiyor demektir; terminal ≠ araç.

### 4.3 CAL_bup "Rota" sekmesi

- **Renkler:** 6 plasiyerin her birine sabit, birbirinden kolay ayrılan bir renk. Üstte renkli
  plasiyer düğmeleri: birine basınca yalnız o plasiyerin çizgisi ve konumu öne çıkar, diğerleri
  soluklaşır (tamamen gizleme seçeneği de olur). "Tümü" ile hepsi birlikte.
- **Yakınlaştırma:** fare tekerleği / iki parmakla sokak düzeyine (bina ve kapı seviyesine
  yakın) kadar iner. Not: haritanın gösterdiği konum, terminal GPS'inin doğruluğu kadardır —
  açık havada genelde **3–10 m**, dar ve yüksek binalı sokaklarda **10–30 m** sapabilir. Bu
  yüzden her nokta için doğruluk değeri de saklanır, haritada küçük bir halka olarak gösterilir.
- **Müşterinin kesin konumu:** tek bir GPS noktasına değil, o müşteride yapılan **birden çok
  duraklamanın ortalamasına** dayanır (her ziyarette daha da netleşir); gerekirse merkezden
  haritada tutup sürükleyerek düzeltilir ve "kesin" diye kilitlenir.
- **Canlı görünüm:** her terminalin son konumu, ne kadar zamandır orada olduğu, son konumun
  ne kadar eski olduğu (ör. "12 dk önce — bağlantı yok"), pil durumu.
- **Rota görünümü:** plasiyer veya terminal + zaman aralığı seçilir; harita çizgisi, duraklar
  (numaralı), toplam km, sürüş süresi, durak süresi.
- **Zaman kaydırıcısı:** rotayı baştan sona oynatma ("o saatte neredeydi?").
- **Yönetim:** terminal listesi, takip aç/kapa, atama girişi.
- **Harita sınırı:** harita İzmir + Aydın + Manisa sınırları içinde açılır, dışına kaydırılamaz. Sınır
  dışına çıkan nokta **silinmez**, listede "bölge dışı" diye işaretlenir (veri kaybı olmasın).
- Erişim: CAL_bup bugün yalnız Ali'nin Google hesabına açık. Yönetim ekibi de görecek (K26) →
  onlara Rota sekmesi için ayrıca erişim açılmalı (§8 soru 3b).

### 4.4 Durak ve müşteri eşleştirme

- **Durak:** araç belirli bir yarıçapta (ör. 50–100 m) belirli süreden uzun (ör. 3 dk) kalırsa
  durak sayılır; başlangıç–bitiş saati ve süresi tutulur. Eşikler ayarlanabilir olmalı.
- **Müşteri konumu nereden gelir?**
  1. Sanal POS'ta tahsilat yapıldığı anın konumu o cariye yazılır → müşteri konumları zamanla
     kendiliğinden öğrenilir.
  2. Oluşturulmakta olan adres listesi (K18) içe aktarılır. Adres → koordinat çevirisi
     (geocoding) yaklaşık konum verir; dar sokaklarda kesin konum yine ziyaret duraklarından
     öğrenilir. Listede cari adı/VKN mutlaka olsun ki Sanal POS carileriyle eşleşsin; koordinat
     (Google Maps'ten kopyalanan enlem, boylam) eklenebilirse en iyisi.
  3. CAL_bup'ta haritadan elle düzeltme.
- **Sonra:** her durak en yakın bilinen müşteriyle eşleştirilir → "Müşteri X, 14:05–14:32".

### 4.5 Km ve süre hesabı

- Ardışık noktalar arası mesafe toplanır; **GPS titremesi ayıklanır** (doğruluğu kötü noktalar,
  dururken oluşan sahte hareket, imkânsız hızlar).
- Ayrı ayrı gösterilir: sürüş süresi, durak süresi, motor çalışır bekleme (hız ≈ 0 ama durak
  eşiği altında; trafik/rölanti tahmini).

### 4.5b Günlük özet (plasiyer başına, gün gün saklanır)

Her plasiyer için her gün bir özet kaydı oluşur (24 saatlik rota iki takvim gününe taşarsa
gece yarısında bölünür; rota görünümünde yine tek parça izlenebilir):

| Bilgi | Nasıl hesaplanır |
|-------|------------------|
| Günlük km | temizlenmiş noktalar arası mesafe toplamı |
| Ortalama hız | sürüş km'si ÷ sürüş süresi (durak süreleri hariç; ayrıca "tüm gün ortalaması" da gösterilebilir) |
| En yüksek hız | titreme ayıklandıktan sonra |
| Sürüş / durak / bekleme süresi | §4.5 |
| Durak ve müşteri sayısı | §4.4 |
| **Harcanan yakıt (L)** | günlük km × aracın 100 km tüketimi ÷ 100 |
| **Yakıt tutarı (₺)** | yakıt (L) × o günün litre fiyatı |

Yakıt **tahminidir**: aracın ortalama tüketimi (L/100 km) ve yakıt fiyatı merkezden girilir.
Gerçek yakıt fişleri girilirse tahmin ile gerçek karşılaştırılabilir (fikir havuzu).
CAL_bup'ta tarih seçilip geçmiş günlerin özeti ve rotası açılır; günler tablo olarak
karşılaştırılır, Excel'e aktarılabilir.

### 4.7 Erken uyarılar (K21)

**Uyarılar yalnız merkeze gider (K24); terminalde hiçbir uyarı gösterilmez.**
Rota sekmesinin üstünde bir **uyarı şeridi**; her uyarı tıklanınca haritada o ana/konuma gider.
Eşikler merkezden ayarlanır. Aday uyarılar:

| Uyarı | Örnek |
|-------|-------|
| Veri kesildi | 15 dk'dan uzun konum gelmiyor (depo dışında) |
| Kurcalama | konum kapatıldı, izin geri alındı, uçak kipi, sahte konum (§4.1b) |
| Beklenmedik uzun duruş | müşteri/depo olmayan yerde 30 dk'dan uzun |
| Bölge dışı (**kararlaştırıldı, K27**) | İzmir/Aydın/Manisa dışına çıkış → basit bildirim tarzı alarm |
| Mesai dışı hareket | gece belirlenen saatlerde araç hareketi (24 saatlik rotası olan araçlar hariç tutulabilir) |
| Hız aşımı | ör. 110 km/s üstü belirli süre |
| Ani duruş (olası kaza) | yüksek hızdan aniden sıfıra ve hareketsizlik |
| Pil kritik | terminal %15 altı |

İleride: uyarının telefona/e-postaya bildirim olarak gitmesi (fikir havuzu).

### 4.6 Analiz ve yakıt tasarrufu (sonraki aşama)

- Günlük/haftalık plasiyer karşılaştırması: km, müşteri sayısı, müşteri başına km, durak süresi.
- **Daha iyi sıra önerisi:** o gün gidilen müşteriler başka sırayla gezilse kaç km tasarruf
  olurdu (gezgin satıcı problemi; yol ağı üzerinden mesafe).
- Tekrarlayan gereksiz dönüşler, aynı bölgeye gün içinde iki kez gidiş.
- Uzun rölanti/bekleme noktaları.
- Araç tüketimi (L/100 km) girilirse tahmini yakıt ve maliyet.
- Planlanan müşteri listesi varsa: gidilmeyen müşteriler, plan dışı duraklar.

## 5. Harita altlığı

| Seçenek | Artı | Eksi |
|---------|------|------|
| OpenStreetMap hazır karo sunucusu | ücretsiz, hızlı başlar | kullanım kuralları ağır kullanıma izin vermez; atıf zorunlu |
| Ticari vektör harita (MapTiler, Stadia vb.) | düzenli, ücretsiz kota çoğu zaman yeter | anahtar gerekir, kota izlenmeli |
| Google Maps | tanıdık görünüm | ücretli (aylık ücretsiz kredi var), faturalandırma hesabı gerekir |
| **Yalnız İzmir+Aydın+Manisa haritasını kendimiz barındırmak** (PMTiles) | dışarıya bağımlılık yok, CAL_bup güvenlik kurallarına uyar | dosya boyutu ve Firebase ücretsiz trafik sınırı hesaplanmalı |

Öneri: ilk denemede ticari bir sağlayıcının ücretsiz kotası; sonra kullanım netleşince kendi
barındırma değerlendirilir. CAL_bup'un güvenlik başlığı (CSP: `img-src`, `connect-src`) seçilen
sağlayıcıya göre genişletilmeli.

## 6. Kapasite ve maliyet (kaba hesap)

Firebase Spark (ücretsiz) günlük sınırlar: 20.000 yazma, 50.000 okuma, 1 GB depolama.

- Nokta başına ayrı kayıt **değil**, 1–2 dakikalık **paketler** yazılır.
- **6 terminal** (K9) × 24 saat × saatte 30–60 paket ≈ 4.300–8.600 yazma/gün (+ canlı konum
  güncellemesi aynı pakette) → sınırın **rahatça altında**. Ücretsiz plan yeter.
- Okuma: Rota sekmesi gün boyu açık kalsa bile birkaç bin okuma/gün.
- Depolama: 6 terminal × günde ~1,5 MB ≈ **3 ayda ~130 MB** (1 GB sınırının çok altında).
- **Saklama 3 ay (K14):** 90 günden eski ham noktalar ve günlük özetler her gece kendiliğinden
  silinir. (Günlük özet çok küçük olduğu için ileride yıl karşılaştırması istenirse yalnız
  özetler daha uzun tutulabilir — şimdilik karar 3 ay.)

## 7. Güvenlik

- Konum kayıtlarını **yalnız terminalin kendisi yazar**, yalnız yönetici rolü okur.
  Plasiyerler ve diğer kullanıcılar birbirinin konumunu göremez (Firestore kuralları).
- Takip aç/kapa ve atama yalnız yönetici rolüyle; her değişiklik denetim kaydına (`denetim`)
  düşer: kim, ne zaman, neyi değiştirdi.
- Mevcut kart kasası, CVV kararı, DenizPay akışı bu işten etkilenmez.
- **Hesap (K19):** terminaller şu an Ali'nin (yönetici) hesabıyla giriyor. Konum yetkisi bu
  hesaba bağlanırsa terminaldeki herkes teorik olarak tüm konumları okuyabilir veya takibi
  kapatabilir. Bu yüzden konum yazımı için her terminale **ayrı, yalnız yazabilen bir cihaz
  kimliği** verilir (kurulumda araç seçilirken oluşur); konumu okuma ve takip ayarı yalnız
  CAL_bup'taki yönetici girişine açıktır. Ali'nin hesabı terminallerden kaldırıldığında konum
  işi etkilenmez.

## 8. Açık sorular

1. ~~Kaç terminal ve kaç plasiyer var?~~ → 6/6 (K9), hepsi Zebra TC15 (K16).
2. Terminallerde MDM var mı (bkz. §4.1 açıklama)? → **bilgi işleme sorulacak.**
3. ~~Haritayı kimler görecek?~~ → Ali + yönetim ekibi, sonra genişletilebilir (K10, K26).
3b. Yönetim ekibi kaç kişi, hangi Google hesaplarıyla girecek? (Erişim açmak için gerekir.)
4. ~~Müşteri adresleri var mı?~~ → oluşturuluyor (K18); hazır olunca biçimi birlikte bakılacak.
5. ~~Terminal hesabı?~~ → kurulumda araç seçimi (K17); Sanal POS şimdilik Ali'nin hesabıyla
   (K19). Tahsilat ↔ durak eşleştirmesi tahsilat anındaki terminalin araç kaydından yapılır.
5c. ~~Araç takip var mı?~~ → var, maliyetli (K23). **Ali bilgilerini sonra gönderecek (17 Kasım).** Açık kalan: hangi firma/sistem; geçmiş
   rota verisi Excel/CSV olarak alınabiliyor mu (geçiş dönemi karşılaştırması için)? Araç
   takibi tamamen mi kaldırılacak, yoksa azaltılacak mı?
5d. ~~Deponun konumu?~~ → K25 (Bornova). Açık kalan: terminali depoya bırakanlar hangi plasiyerler?
5b. ~~TC15'lerin Android sürümü?~~ → Android 13 (SDK 33), 28 Ekim okumasından; bildirim gizleme
   mümkün. (Diğer 5 terminal de aynı sürümde mi, kurulumda bakılacak.)
6. Yakıt için: her aracın ortalama tüketimi (L/100 km) ve yakıt türü (dizel/benzin) nedir?
   Plasiyer hep aynı araçla mı çıkıyor, yoksa araç da değişiyor mu? Yakıt fiyatı elle mi
   girilsin?
7. ~~Ham konumlar ne kadar saklanacak?~~ → 3 ay (K14).
8. ~~Bölge dışı uyarısı?~~ → evet, İzmir/Aydın/Manisa dışı basit alarm (K27).
8b. ~~Alarm nereye?~~ → önce CAL_bup içi + tarayıcı bildirimi (K28).
9. Merkezden plasiyere yönlendirme (ör. "sıradaki müşteri" listesi, mesaj) ileride istenecek mi?
   Bu ayrı bir özellik; şimdilik yalnız konum toplama kararlaştırıldı.

## 9. Önerilen aşamalar (16 Kasım 2026 kararlarına göre)

| Aşama | İçerik | Bitti sayılır |
|-------|--------|---------------|
| 0 | Kalan açık sorular (§8): TC15 Android sürümü, MDM, araç tüketimleri, depo konumu, araç takip verisi; harita sağlayıcı seçimi | §8 kapandı |
| 1 | Android: ön plan konum hizmeti, akıllı sıklık, internetsiz birikme, cihaz kimliği + kurulumda araç seçimi (K17), merkezden aç/kapa, kurcalama kayıtları. **Ali'nin kendi telefonunda** 24 saat deneme | pil, kesinti, birikme ölçüldü; terminalde görünen hiçbir şey yok (K24) |
| 2 | CAL_bup **Rota** sekmesi: canlı harita, renkli plasiyerler + seçince öne çıkma, sokak düzeyi zoom, uydu, İzmir+Aydın+Manisa sınırı, rota çizgisi, zaman kaydırıcısı | gerçek bir günlük rota doğru çiziliyor |
| 3 | Durak tespiti, depo bölgesi, km/hız/yakıt günlük özeti (gün gün, 3 ay), araç listesi ve atama yönetimi | günlük özet elle ölçümle tutuyor |
| 4 | Erken uyarılar (yalnız merkez) ve müşteri konumu öğrenme/eşleştirme | örnek kurcalama denemeleri uyarı üretiyor |
| 5 | Zebra TC15'te kabul: StageNow kilidi, bildirim gizleme (emanet cihaz — her adım öncesi Ali'ye sorulur); **araç takip sistemiyle birkaç hafta paralel karşılaştırma** | terminal rotası araç takibiyle tutarlı |
| 6 | Analiz ve yakıt tasarrufu: karşılaştırmalar, sıra önerisi, haftalık rapor | yöneticiye ilk haftalık rapor |

**Görsel taslak (Ali beğendi, 16 Kasım: "gayet iyi görünüyor"; Aşama 2 bu görünüme göre yapılır):** `docs/route-taslak/rota-taslak.html` — tarayıcıda açılır; örnek (uydurma)
verilerle Rota sekmesinin nasıl görüneceğini gösterir. Rotalar yollara oturmuyor (düz çizgi
parçaları); gerçek sürümde GPS noktaları sık olduğu için çizgi yolu izler.

## 10. Fikir havuzu (sıralanmamış, sonra değerlendirilecek)

- Plasiyerin gün sonu özeti yöneticiye otomatik rapor (CAL_bup içinde veya Excel çıktısı).
- Tahsilat haritası: hangi müşteride ne kadar tahsilat yapıldı, rota üzerinde.
- Müşteri ziyaret sıklığı: uzun süredir gidilmeyen müşteriler.
- Bölge yoğunluk haritası (hangi semtlerde zaman geçiyor).
- Terminal şarjı/çevrimdışı uyarısı.
- Haftalık planlı rota ile gerçekleşenin karşılaştırması.
- Gerçek yakıt fişlerinin girilip tahmini yakıtla karşılaştırılması.
- Uydu görüntüsüne geçiş düğmesi (dar sokakta binayı tanımak için).

_Yeni fikirler bu bölüme eklenir; karar verilenler §2'ye taşınır._
