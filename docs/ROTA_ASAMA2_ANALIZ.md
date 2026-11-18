# Rota Aşama 2 — CAL_bup "Rota" sekmesi: analiz ve plan

> 17 Kasım 2026 gece. Ali: "yapılması gereken her şeyi iyice analiz et, raporlayalım, sonra demo
> olarak gösterdiğin örneği yapalım." Kararlar `ROUTE_PLANI.md` (K1–K29), terminal tarafının
> teknik mimarisi `ROTA_MIMARI.md` (M1–M18). Bu dosya Aşama 2'nin (harita tarafı) analizidir.

## 0. Özet (Ali için)

Telefonundan gelen konumlar şu an canlı Firebase'de birikiyor ama göreceğin bir ekran yok. Taslakta
beğendiğin "Rota" sekmesini CAL_bup'ta gerçek veriyle kurmak için **altı parça** gerekiyor:

1. **CAL_bup'ın konum verisine güvenli bağlanması** (Google hesabınla, ayrı bir yetki listesiyle).
2. **Harita** (sokak ve uydu görünümü, İzmir–Aydın–Manisa sınırı).
3. **Veriyi okuma ve bilgisayarda saklama** (her konum bir kez indirilir; ücretsiz sınır korunur).
4. **Hesaplar**: rota çizgisi, duraklar, km, ortalama hız, yakıt, depoda geçen süre.
5. **Uyarılar**: veri kesildi, konum kapatıldı, bölge dışı, hız, uzun duruş.
6. **Yönetim ekranları**: terminal onayı, takip aç/kapa, araç listesi, plasiyer ataması, depo yeri.

Analizde **önemli bir bulgu** var: telefonun ilk 10 dakikada 13 parça gönderdi. Bu hızla 6 terminal
günde ~22.000 yazma yapar; Firebase'in ücretsiz sınırı 20.000. Çözüm basit ama terminal uygulamasında
küçük bir güncelleme ister (§3.6). Senden **beş karar** gerekiyor (§4).

## 1. Hedef: taslağın gerçek veriyle karşılığı

| Taslaktaki parça | Gerçekte neyden gelir |
|---|---|
| Plasiyer listesi, renkler, "bugün x km" | `rotaAraclar` (araç no, plasiyer, renk) + `rotaAtamalar` (hangi terminal hangi araçta) + günün hesabı |
| Harita: canlı konum noktaları | `rotaSonDurum` (terminal başına tek belge, canlı dinlenir) |
| Rota çizgisi, duraklar | `rotaParcalar` (değişmeyen nokta paketleri) → temizleme + durak bulma (§3.7) |
| Zaman kaydırıcısı, "Şimdi" | Günün noktaları zamana göre; kaydırıcı o ana kadarki çizgiyi ve konumu gösterir |
| Sokak / Uydu düğmesi | İki harita altlığı (§3.4) |
| Uyarı şeridi | Olaylar (konum kapandı, sahte konum, …) + hesaplanan uyarılar (§3.8) |
| Günlük özet kartları ve tablo | km, sürüş/durak süresi, ortalama hız, müşteri (durak) sayısı, yakıt (L, ₺) |
| Seçili plasiyer: son 7 gün karşılaştırma | Günlük özetler (tarayıcıda hesaplanır ve saklanır) |
| Depo simgesi ve depo bölgesi | `rotaAyar/genel.depolar` (Bornova adresi; konum haritada işaretlenip onaylanır, K25) |
| İl sınırı (İzmir, Aydın, Manisa) | Sınır çizgileri sabit dosya olarak paketin içinde (§3.4) |

## 2. Bugünkü durum (ölçülmüş)

- Terminal hattı canlıda çalışıyor: Ali'nin telefonu (4G77NB) 20:37'den beri gönderiyor. 10 dakikada
  13 parça, 23 nokta; hepsi sözleşme doğrulamasından geçti, boşluk ve çift yok.
- Kapalı alanda noktaların çoğu ağ konumu (~16 m). GPS açık havada gelir.
- Sözleşme (veri biçimi) ve doğrulayıcı hazır: `docs/rota/sozlesme/` (Kotlin ve JS aynı örnekle
  sınanıyor). CAL_bup okuyucusu bunun TypeScript karşılığı olacak.

## 3. Gereken parçalar ve ayrıntıları

### 3.1 Kimlik: CAL_bup → Sanal POS Firebase'i

CAL_bup kendi Firebase projesindedir (`bup-siparis`), konum verisi Sanal POS projesindedir
(`bup-sanal-pos-izmir`). Rota sekmesi ikinci, ayrı bir Firebase bağlantısı açar ("rota" adlı uygulama).

- **Giriş:** Rota sekmesine ilk girişte **Google hesabıyla** bir kez onay penceresi (Sanal POS projesine).
  CAL_bup girişiyle aynı hesap ama Firebase her projede ayrı oturum ister; ikinci pencere bundandır.
  Oturum tarayıcıda kalır, her açılışta sorulmaz.
- **Gerekli canlı ayarlar (Ali onayı):**
  1. Sanal POS projesinde **Google giriş sağlayıcısını** açmak (destek e-postası = Ali'nin Gmail'i).
  2. Yetkili alan adlarına `cal-bup-ali.web.app` eklemek.
  3. İlk rota yöneticisi kaydı: `rota_yonet.mjs ilk-yonetici <Ali'nin Gmail'i>` (`rotaYetkileri`).
- **Neden güvenli:** kurallar yalnız Google girişli ve `rotaYetkileri`'nde aktif kaydı olan hesaba
  okuma verir (M4). CAL_bup'ın koduna sahip olmak veriyi açmaz; veri anahtarı sunucudadır.

### 3.2 Yönetim ekibinin erişimi (K26) — **karar gerekiyor**

CAL_bup bugün **yalnız Ali'nin** Google hesabına açılır (uygulama dosyaları şifreli, anahtar tek
sahibe verilir; `OZEL_ERISIM.md`). Yönetim ekibi haritayı görecekse üç yol var:

| Yol | Nasıl | Artı | Eksi |
|---|---|---|---|
| **A. Önce yalnız Ali** (önerilen ilk adım) | Rota sekmesi CAL_bup'ta, yalnız Ali | Hiçbir erişim değişikliği yok; hızlı | Yönetim şimdilik göremez |
| B. CAL_bup'ı yönetime de açmak | Erişim listesine e-postalar eklenir | Tek site | Yönetim CAL_bup'ın **bütün araçlarını** (rapor, POS, notlar) açabilir hâle gelir; Ali'nin verileri tarayıcısında kalır ama araçlar görünür |
| C. Yönetime ayrı "Rota" sayfası | Sanal POS projesinde yalnız haritayı içeren ayrı site | Yönetim yalnız haritayı görür; CAL_bup tek kişilik kalır | Aynı ekran iki yerde yayınlanır (kod ortak tutulur) |

Öneri: **A ile başla, yönetim sırası gelince C.** Ekran kodu baştan bağımsız bir modül olarak
yazılır; C'ye geçiş yalnız ikinci bir yayın kabuğu demektir.

### 3.3 Güvenlik başlıkları (CSP)

CAL_bup her dış bağlantıyı sayfa başlığında tek tek izinler (`vite.config.ts`). Eklenecekler:

| Başlık | Eklenecek | Neden |
|---|---|---|
| `connect-src` | `https://firestore.googleapis.com` | Konum verisi |
| `img-src` | harita karo adresleri (§3.4) | Harita resimleri |
| `script-src` | `https://apis.google.com` | Google giriş penceresi (Firebase) |
| `frame-src` | `https://bup-sanal-pos-izmir.firebaseapp.com` | Giriş yardımcı çerçevesi |

Joker alan adı eklenmez. Harita kütüphanesi (Leaflet) pakete gömülür, CDN'den yüklenmez.

### 3.4 Harita altlığı ve sınırlar — **karar gerekiyor**

| Seçenek | Durum (17 Kasım'da kaynaklarından bakıldı) |
|---|---|
| **OpenStreetMap sokak haritası** | Uygun. Kullanım kuralı web sitesinin "Referer" bilgisi göndermesini şart koşuyor; CAL_bup bunu genelde kapatıyor → yalnız harita karolarında `strict-origin-when-cross-origin` açılır (Leaflet `referrerPolicy`). Atıf yazısı zorunlu; yoğun kullanım yasak (birkaç yönetici sorun değil). |
| MapTiler (sokak + uydu) | **Ücretsiz plan ticari kullanıma kapalı** (resmi şartlar). Şirket kullanımı ücretli plan ister (aylık ücret; güncel fiyat sitesinden teyit edilmeli). |
| Esri uydu görüntüsü (taslakta) | Şartlar belirsiz: Esri ana lisans sözleşmesine bağlı; hesap gerekip gerekmediği ve ticari kullanım netleşmedi. **Netleşmeden kullanılmaz.** |
| Google Maps | Faturalandırma hesabı ister ("billing kapalı" kararına aykırı). |

Öneri: **sokak = OpenStreetMap** (taslaktaki görünüm). **Uydu: ilk sürümde yok**; ihtiyaç olursa
ücretli bir sağlayıcı (MapTiler vb.) ya da Esri'nin yazılı şartlarının teyidiyle sonra eklenir —
düğme yeri hazır tutulur.
Kaynaklar: OSM karo kuralı https://operations.osmfoundation.org/policies/tiles/ ve
https://wiki.openstreetmap.org/wiki/Blocked_tiles ; MapTiler şartları https://www.maptiler.com/cloud/terms/ ;
Esri https://goto.arcgis.com/maps/World_Imagery .
**İl sınırları:** OpenStreetMap'ten İzmir, Aydın, Manisa sınırları sadeleştirilip pakete gömülür
(~50–100 KB; ODbL atfı). Harita bu alanla sınırlanır; bölge dışı uyarısı aynı çizgiyi kullanır (K27).

### 3.5 Veri okuma ve bilgisayarda saklama

- **Parçalar hiç değişmez** (terminal yalnız ekler). Bu yüzden her parça bir kez indirilir ve
  tarayıcıda (IndexedDB) saklanır; sonraki açılışlarda yalnız **yeni** parçalar sorulur.
- Sorgu: `cihaz == X ve alindi > son görülen` (Firestore bileşik dizin gerekir; `firestore.indexes.json`).
- Canlı konum yalnız `rotaSonDurum` dinlenerek alınır (6 belge); sekme görünmüyorken dinleme durur.
- **Okuma hesabı (Spark: günde 50.000):** gönderim 2 dk'da bir olursa terminal başına günde ≤720
  parça → 6 terminal 4.320 okuma (her parça bir kez) + canlı dinleme ~4.300 → **günde ~9.000**.
  Birkaç yönetici aynı anda açsa bile sınırın altında.
- **Saklama süresi:** tarayıcıdaki kopya da 90 gün (K14); eskiler açılışta silinir. Çıkışta (Google'dan
  çıkış) rota önbelleği temizlenir. Önbellek yalnız rota verisini içerir.

### 3.6 Yazma kotası — **bulgu ve karar**

Ölçüm: Ali'nin telefonu 10 dakikada 13 parça (+13 durum güncellemesi). Gönderici, kuyrukta kayıt
oldukça en geç 60 sn'de bir gönderiyor. 24 saat sürerse terminal başına ~3.700 yazma → 6 terminal
**~22.000/gün > 20.000 sınır**. Sınır aşılırsa o gün yazmalar reddedilir; noktalar kaybolmaz
(terminalde birikir) ama canlı harita durur ve Sanal POS'un tahsilat kaydı da etkilenebilir.

Seçenekler:

| | Gönderim aralığı | Canlı gecikme | Yazma/gün (6 terminal) | Ücret |
|---|---|---|---|---|
| **A (önerilen)** | hareket 2 dk, durgun 5 dk, depoda 15 dk — merkezden ayarlanabilir | en çok 2 dk | ~5.000–9.000 | yok |
| B | 1 dk | en çok 1 dk | ~14.000–17.000 | yok ama sınıra yakın |
| C | 30 sn, Blaze (ücretli) plan | 30 sn | ~40.000–70.000 | ayda tahminen 1–3 $ (faturalandırma açılır; bugünkü "billing kapalı" kararını değiştirir) |

Noktalar yine 15 sn'de bir **alınır** (rota çizgisi ayrıntılı kalır); yalnız sunucuya **gönderme** seyrekleşir.
A için terminal tarafında küçük değişiklik: `rotaCihazlar`'a `gonderimSn` alanı (kural + Kotlin) →
**0.13.1 APK**. Ali'nin telefonundaki 24 saat deneme bu değişiklik gelene kadar mevcut hızla sürer
(tek terminal, sınırın çok altında).

### 3.7 Hesaplar (saf TypeScript, birim testli)

Hepsi tarayıcıda, ham noktadan; ham veri değişmez (M10):

1. **Temizleme:** doğruluğu kötü (zayıf), sahte, imkânsız hız (>180 km/s sıçrama) ve dururken GPS
   titremesi ayıklanır (silinmez, işaretlenir).
2. **Durak:** 75 m çember içinde 3 dk'dan uzun kalış → durak (başlangıç, bitiş, süre). Eşikler ayarlı.
3. **Depo:** depo bölgesine giriş/çıkış → "Depoda" süresi km'ye ve sürüşe girmez (K22).
4. **Km:** temiz noktalar arası mesafe toplamı; GPS kesintisinde (ör. tünel) iki uç arası düz çizgi
   sayılır ve "tahmini" işaretlenir.
5. **Ortalama hız:** sürüş km'si ÷ sürüş süresi (durak hariç); en yüksek hız ayrıca.
6. **Yakıt:** km × aracın 100 km tüketimi ÷ 100; ₺ = L × o günün fiyatı (elle girilir). Araç
   bilgisi girilene kadar "—".
7. **Gün:** Türkiye saatiyle 00:00'da bölünür; 24 saatlik rota kaydırıcıda tek parça izlenebilir.
8. **Plasiyer ↔ terminal:** o andaki geçerli atamaya göre (K5); atama değişirse rota bölünür.
9. **Saat oynaması:** GPS zamanı ile cihaz saati / sunucu alım zamanı farkı → uyarı.

Doğrulama: yapay rotalarla birim testleri + Ali'nin telefonunun gerçek günü (elle ölçümle karşılaştırma,
"bitti" ölçütü ROUTE_PLANI §9).

### 3.8 Uyarılar (K27, K28)

Yalnız CAL_bup açıkken: sekmenin üstündeki şerit + isteğe bağlı tarayıcı bildirimi (bir kez izin
istenir). Kurallar: veri kesildi (15 dk, depo dışında), konum kapatıldı/izin yok, sahte konum,
cihaz kapandı/açıldı, pil düşük, saat değişti, kuyruk taştı, **bölge dışı** (İzmir/Aydın/Manisa dışı),
hız aşımı (eşik ayarlı), uzun duruş (müşteri/depo dışı 30 dk). Her uyarıya tıklayınca harita o ana gider.

### 3.9 Yönetim ekranları (Rota sekmesinin "Ayarlar" bölümü)

- Bekleyen terminaller (kod, model) → onayla, ad ver.
- Takip aç/kapa (terminal başına), gönderim/örnekleme aralıkları.
- Araç listesi: no, plasiyer, renk, yakıt türü, tüketim.
- Atama defteri: terminal → araç, başlangıç zamanı (yalnız ekleme; düzeltme yeni kayıtla).
- Depo yeri: haritada işaretle → onayla (K25).
- Yetkiler: izleyici ekle/kapat (yönetim ekibi için; §3.2'ye bağlı).
Her değişiklik kuraldaki denetim kaydıyla yazılır (zaten hazır, Aşama 1).

### 3.10 Kod yapısı (CAL_bup)

CAL_bup katman kuralları korunur:

| Klasör | İçerik |
|---|---|
| `src/cekirdek/rota/` | sözleşme doğrulayıcı (TS), temizleme, durak, km, gün bölme, uyarı kuralları — saf |
| `src/platform/rota/` | Firebase "rota" bağlantısı, Google girişi, Firestore okuma, IndexedDB önbelleği |
| `src/arayuz/sayfalar/rota/` | Rota sekmesi (taslağın React karşılığı), tembel yüklenir |
| `src/arayuz/rota.ts` | `#/rota` adresi; kenar çubuğuna "Rota" |

Harita kütüphanesi ve sınır dosyası yalnız Rota sekmesi açılınca yüklenir (diğer ekranlar yavaşlamaz).

### 3.11 Test ve doğrulama

- Saf hesaplar: vitest birim testleri (yapay rotalar, sınır durumları).
- Sözleşme: `docs/rota/sozlesme/parca-ornek.json` TS okuyucuyla da sınanır (Kotlin = JS = TS).
- Tarayıcı: Firebase emülatörü + yapay terminal verisiyle Playwright (giriş, harita, kaydırıcı, onay).
- Gerçek: Ali'nin telefonunun verisiyle canlı görünüm; km'nin elle ölçümle karşılaştırılması.
- CAL_bup'ın mevcut `npm run kontrol`, tarayıcı, performans ve erişim testleri geçmeli.

### 3.12 Yayın

CAL_bup 1.45.0 olarak şifreli özel yayın (`yayin:ozel`), **Ali'nin onayıyla**. Öncesinde Sanal POS
projesindeki Google sağlayıcısı ve yetkili alan ayarları (Ali onayı) yapılmış olmalı.

## 4. Ali'nin kararları

> **17 Kasım 2026 gece cevaplandı:** 1 → önce yalnız Ali (K30), 2 → 2 dk ücretsiz (K31), 3 → yalnız sokak (K32),
> 4 → evet, gerektiğinde (K33). 5 (araç bilgileri) sonra.

1. **Yönetim erişimi:** önce yalnız Ali (A), sonra yönetime ayrı Rota sayfası (C)? (§3.2)
2. **Gönderim aralığı:** ücretsiz kalıp en çok 2 dk gecikme (A) mi, yoksa ücretli plan (C) mı? (§3.6)
3. **Uydu görüntüsü:** ilk sürümde yalnız sokak haritası (ücretsiz, OpenStreetMap) mı, yoksa ücretli bir uydu sağlayıcısı mı? Ücretsiz uydu seçeneklerinin şirket kullanımı ya kapalı ya belirsiz. (§3.4)
4. **Canlı ayarlar:** Sanal POS projesinde Google girişi + yetkili alan + ilk rota yöneticisi (Ali'nin Gmail'i). (§3.1)
5. **Araç bilgileri:** her aracın no'su, plasiyeri, yakıt türü ve 100 km tüketimi (yakıt hesabı için; sonra da girilebilir).

## 5. İş sırası ve "bitti" ölçütleri

| Adım | İçerik | Bitti sayılır |
|---|---|---|
| 2a | Saf çekirdek: TS sözleşme doğrulayıcı, temizleme, durak, km, gün, uyarılar | birim testleri; örnek parça Kotlin=JS=TS |
| 2b | Firebase "rota" bağlantısı + Google girişi + önbellek (emülatörle) | emülatörde giriş, okuma, önbellekten ikinci açılış |
| 2c | Rota sekmesi: taslaktaki görünüm, canlı konum, çizgi, kaydırıcı, duraklar, özet | yapay veriyle Playwright; taslakla görsel eşleşme |
| 2d | Yönetim ekranları (onay, takip, araç, atama, depo) | emülatörde kural testleriyle uyumlu yazım |
| 2e | 0.13.1 terminal: merkezden gönderim aralığı (`gonderimSn`) | kural + Kotlin testleri; Ali'nin telefonunda ölçüm |
| 2f | Canlı ayarlar (Ali onayı) + CAL_bup 1.45.0 yayını (Ali onayı) | Ali kendi verisini Rota sekmesinde görür |

Demo: 2c bitince — yayından önce — Ali'ye **kendi telefonunun gerçek verisiyle** yerelde gösterilir.

## 6. Riskler ve bilinmeyenler

- Uydu görüntüsünün lisansı (karar 3); ilk sürüm uydusuz yapılırsa risk yok.
- Firestore TTL'in Spark'ta çalışması (M15) — çalışmazsa yönetici temizliği (kuralı hazır).
- Kapalı alanda GPS yok: noktalar ağ konumu (~15–50 m); durak/müşteri eşleşmesi bunu tolere etmeli.
- Xiaomi gibi telefonlarda "otomatik başlatma" elle açılmalı (Ali'nin telefonunda yapıldı); TC15'te
  gerekmez (Android standardı) ama Aşama 5'te bakılacak.
- Yönetim ekibi erişimi (§3.2) CAL_bup'ın tek sahipli güvenlik modelini etkiler; C yolu bunu korur.

## 7. Durum (18 Kasım 2026 sabah)

CAL_bup dal `rota` (yerelde, push/yayın yok): 2a çekirdek, 2b Firebase+önbellek, 2c ekran, **2d yönetim
ekranları** bitti (Rota → Ayarlar: onay, takip/aralıklar, araç ataması, araçlar, depo; izleyici yetkileri
K30'a kadar yok). **2e** Sanal POS dal `rota-0.13.1` (yerelde, yayın yok): merkezden gönderim aralığı
(`gonderimSn`, varsayılan 120) ve **bekçi** (Ali'nin telefonunda 17 Kasım 21:25'te Google Play Hizmetleri
güncellemesiyle hizmet öldü, 9 saat veri gelmedi; ROTA_MIMARI M19). Kanıt: `bash tools/rota_test.sh
emulator-5584` (bekçi dahil), emülatörde yönetim yazımları gerçek kurallarla
(`CAL_bup/tools/rotaEmulatorDenemesi.mjs`), sürüm APK 0.13.1 derlendi ve denetlendi.
Kalan **2f (Ali onayıyla)**: Google sağlayıcı (konsolda Ali), yetkili alan `cal-bup-ali.web.app`
(`auth_duzenle.mjs`), ilk rota yöneticisi, yeni kuralların canlıya gönderilmesi, 0.13.1'in telefona
kurulumu/yayını, CAL_bup 1.45.0 yayını.
