# Rota — teknik mimari

> 17 Kasım 2026. Ali: "güvenli, sağlam temelli, mühendislik açısından iyi kurulmuş bir proje
> yapalım; sana güveniyorum." Bu dosya **nasıl** yapılacağını, `ROUTE_PLANI.md` **ne**
> yapılacağını anlatır. Kararlar orada (K1–K29), teknik kararlar burada (M1–M18).
> Kod bu dosyaya uymak zorundadır; uymayan bir gereksinim çıkarsa önce bu dosya değişir.

## 1. Tasarım ilkeleri

1. **Veri kaybolmaz.** Terminalde alınan her nokta, sunucuda kayıt görülene kadar cihazda kalıcı
   olarak durur. İnternet kesintisi, yeniden başlatma ve uygulamanın öldürülmesi nokta kaybettirmez.
2. **Ham veri değiştirilmez.** Terminal yalnız ekler; düzeltme, temizleme ve yorum (durak, km,
   yakıt) okuyan tarafta yapılır. Algoritma sonradan iyileşirse geçmiş yeniden hesaplanabilir.
3. **En az yetki.** Her terminal yalnız kendi alanına yazar, başkasını okuyamaz. Konumu yalnız
   rota yetkisi verilmiş Google hesapları okur. Takip ayarını yalnız rota yöneticisi değiştirir.
4. **Terminaldeki oturuma güvenilmez.** Terminaller Sanal POS'a şimdilik Ali'nin hesabıyla
   giriyor (K19). Rota yetkisi bu hesaba ve terminaldeki parolalı oturuma **bağlanmaz**.
5. **Sözleşme tek yerde.** Firestore şeması bu dosyada tanımlıdır; yazan (Kotlin) ve okuyan
   (CAL_bup TypeScript) aynı örnek kayıtlarla sınanır.
6. **Saf mantık platformdan ayrı.** Sıklık politikası, parça oluşturma, mesafe vb. Android'e
   dokunmayan saf Kotlin/TypeScript'tir ve birim testleriyle sınanır.
7. **Ücretsiz plan (Spark) içinde.** Cloud Functions/sunucu yok; bütün güvenlik Firestore
   kurallarıyla sağlanır, kotalar §9'da hesaplıdır.

## 2. Teknik kararlar

| # | Karar | Neden |
|---|-------|-------|
| M1 | Konum hattının tamamı **yerel Kotlin**: ön plan hizmeti, konum alma, kuyruk, gönderim, merkez dinleme. Flutter motoru gerekmez. | Uygulama ekranı kapalıyken ve yeniden başlatmadan sonra Dart çalışmaz; arka plan Dart'ı kırılgandır. |
| M2 | Terminal kimliği: Kotlin'de **ikinci, adlı bir FirebaseApp ("rota")** üzerinde **anonim oturum**. Ali'nin Sanal POS oturumundan tamamen ayrı. | Spark'ta sunucu olmadığı için özel jeton üretilemez; anonim kimlik cihaz başına kalıcı ve yalnız o cihazdadır. |
| M3 | **Kayıt merkezde onaylanır.** Terminal kendiliğinden bir *başvuru* bırakır (anonim kimlik + 6 haneli terminal kodu + model). Rota yöneticisi CAL_bup'ta başvuruyu onaylar ve aracı orada seçer. Onaysız terminal hiçbir konum yazamaz. | K17'nin inceltmesi (K29): terminal ekranında araç seçimi yok, terminaldeki oturum rota ayarına dokunamaz. |
| M4 | **Rota yöneticisi/izleyicisi yalnız Google girişli** ve `rotaYetkileri` kaydı olan hesaptır (sunucu kuralı `sign_in_provider == 'google.com'` + doğrulanmış e-posta). Sanal POS'un parolalı yönetici hesabı rota verisini ne okur ne değiştirir. | İlke 4. Terminaldeki Ali oturumunu ele geçiren biri takibi kapatamaz, başkalarının konumunu göremez. |
| M5 | Kalıcı kuyruk: cihazda **SQLite** (Android'in kendi kütüphanesi, ek bağımlılık yok). Rota uygulamasında Firestore'un çevrimdışı önbelleği **kapalı**; tek doğruluk kaynağı kuyruktur. | İki ayrı kuyruk (SQLite + Firestore önbelleği) çift kayıt ve belirsizlik doğurur. |
| M6 | Noktalar **parça** belgeleriyle gönderilir (en çok 240 nokta). Parça kimliği belirlenimcidir: `{cihaz}_{ilkSıra}`. Yalnız oluşturma serbesttir; aynı parça ikinci kez yazılamaz. Gönderim belirsiz biterse cihaz kendi parçasını okuyup var olduğunu görür ve kuyruktan düşer. | Yeniden gönderim güvenli (idempotent); çift nokta veya kayıp olmaz. |
| M7 | Üç zaman tutulur: **GPS zamanı** (uydudan), **cihaz saati**, **sunucu alım zamanı** (`request.time`). | Plasiyer cihaz saatini oynatırsa fark görülür (kurcalama). |
| M8 | Konum kaynağı Android **LocationManager** (GPS + ağ). Google Play Hizmetleri'ne bağlı değil; bir arayüzün arkasında, gerekirse sonra Fused eklenir. | Her Android'de (iData T1 gibi Play'siz cihazlar dahil) ve emülatörde aynı çalışır. |
| M9 | **Akıllı sıklık** saf Kotlin politika sınıfıdır: hareket 15 sn, durgun 120 sn, depoda 300 sn (merkezden ayarlanabilir). | Pil; test edilebilirlik. |
| M10 | Terminal **filtre uygulamaz**, yalnız doğruluğu çok kötü (>500 m) noktaları "zayıf" diye işaretleyip yine gönderir. Titreme ayıklama, durak, km CAL_bup'ta yapılır. | İlke 2. |
| M11 | Kurcalama/olaylar (konum kapandı, izin yok, açılış/kapanış, pil düşük, saat değişti, sahte konum, hizmet yeniden başladı) aynı parçanın `olaylar` listesine girer. | Tek yazma; olay ve rota aynı zaman çizgisinde. |
| M12 | Merkez kumandası: hizmet `rotaCihazlar/{uid}` belgesini dinler. Takip kapalıyken GPS kapalıdır, yalnız dinleme sürer. Hizmet açılış/güncelleme sonrasında kendiliğinden başlar. | K2: düğme yok, merkezden aç/kapa. |
| M13 | Yerel yapılandırma (Firebase proje bilgisi) derlemede `--dart-define-from-file` ile verilen aynı dosyadan `BuildConfig`'e yazılır. | Tek kaynak; Flutter açılmadan hizmet çalışabilir. |
| M14 | Okuyan taraf (CAL_bup) cihaz verisine **güvenmez**: her parça şema sürümüyle doğrulanır, bozuk nokta atlanır ve sayılır, hiçbir alan HTML olarak basılmaz. | Kurallar liste içini tek tek denetleyemez. |
| M15 | Saklama 90 gün: her parçada `silinme` zamanı; Firestore **TTL** politikası (Spark'ta çalıştığı canlıda doğrulanacak). Çalışmazsa CAL_bup'ta rota yöneticisinin açılışta yaptığı temizlik (kural yalnız 90 günden eskiyi silmeye izin verir). | K14. |
| M16 | Terminalde **hiçbir görünür öğe** yok (K24). Yalnız Sanal POS'un yönetici bilgi sayfasında, **parola yeniden sorularak** açılan "Konum kurulumu" bölümü: izinleri ister, terminal kodunu ve hizmet durumunu gösterir. Kurulumu Ali bir kez yapar. | Android izinleri bir kez ekranda verilmek zorunda (StageNow ile verilene kadar). |
| M17 | Android'in zorunlu bildirimi en düşük önemde, sessiz, düğmesiz kanaldadır; Android 13+'ta bildirim izni istenmediği için çubukta görünmez. | K24; TC15 Android 13 (SDK 33) — §8 soru 5b kapandı. |
| M18 | Kurallar ve şema önce, kod sonra: her aşamada önce Firestore kuralı + emülatör testi yazılır. | En az yetkinin kodla değil sunucuyla sağlanması. |

## 3. Bileşenler

```
 Zebra TC15 (Sanal POS APK)                     Firebase bup-sanal-pos-izmir           CAL_bup (tarayıcı)
 ┌───────────────────────────────┐              ┌──────────────────────────┐          ┌──────────────────────┐
 │ RotaHizmeti (foreground svc)  │  anonim      │ rotaBasvurular/{uid}     │  Google  │ Rota sekmesi         │
 │  KonumKaynagi (LocationMgr)   │  oturum      │ rotaCihazlar/{uid}  ◄────┼──────────┤  onay, aç/kapa       │
 │  OrneklemePolitikasi (saf)    ├─────────────►│ rotaParcalar/{uid}_{sıra}├─────────►│  harita, durak, km   │
 │  NoktaKuyrugu (SQLite)        │  yalnız ekler│ rotaSonDurum/{uid}  ─────┼─────────►│  uyarılar            │
 │  Gonderici (parça, yeniden)   │              │ rotaAraclar, rotaAtamalar│◄─────────┤  araç/atama defteri  │
 │  OlayIzleyici (kurcalama)     │◄─────────────┤ rotaAyar/genel (depo)    │          │                      │
 │  MerkezDinleyici              │  okur        │ rotaYetkileri, rotaDenetim│         │                      │
 └───────────────────────────────┘              └──────────────────────────┘          └──────────────────────┘
   Flutter tarafı: yalnız gizli "Konum kurulumu" (izin + durum), MethodChannel "rota".
```

Kotlin paketi: `com.bup.sanalpos.rota`. Saf sınıflar Android sınıfı kullanmaz ve JVM birim
testiyle (`src/test`) sınanır; Android'e dokunanlar emülatörde (`src/androidTest`) sınanır.

## 4. Firestore şeması (sözleşme, şema sürümü 1)

Bütün zamanlar Firestore `timestamp`'tir; cihazın ürettiği zamanlar ayrıca epoch milisaniye
(`int`) olarak tutulur. Koordinatlar WGS84 derece (`double`).

### 4.1 Terminalin yazdıkları

**`rotaBasvurular/{uid}`** — yalnız oluşturulur (uid = terminalin anonim kimliği)

| Alan | Tür | Not |
|------|-----|-----|
| `s` | int | şema = 1 |
| `kod` | string | 6 karakter `[A-HJ-NP-Z2-9]` (karışan harf yok); uid'den türetilir, kurulum ekranında görünür |
| `model`, `uretici` | string ≤ 60 | `Build.MODEL`, `Build.MANUFACTURER` |
| `android` | int | SDK düzeyi |
| `surum` | int | uygulama versionCode |
| `olusturma` | timestamp | `== request.time` |

**`rotaParcalar/{uid}_{ilk:12 hane}`** — yalnız oluşturulur

| Alan | Tür | Not |
|------|-----|-----|
| `s` | int | 1 |
| `cihaz` | string | yazanın uid'si |
| `ilk`, `son` | int | cihazdaki sıra numaraları, `ilk ≤ son`, kimlikteki `ilk` ile aynı |
| `bas`, `bit` | timestamp | ilk/son noktanın GPS zamanı; `bit ≤ alım + 10 dk`, `bas ≥ alım − 30 gün` |
| `alindi` | timestamp | `== request.time` |
| `silinme` | timestamp | `alindi + 90 gün` (TTL) |
| `cihazSaati` | int | gönderim anında cihaz saati (ms) |
| `pil` | int 0–100 | gönderim anında |
| `sarj` | bool | |
| `surum` | int | versionCode |
| `n` | list ≤ 240 | noktalar (aşağıda) |
| `olaylar` | list ≤ 50 | olaylar (aşağıda) |

Nokta (map): `q` sıra (int), `z` GPS zamanı ms (int), `en`, `boy` (double),
`dog` yatay doğruluk m (double), `hiz` m/s (double | null), `yon` derece (double | null),
`yuk` rakım m (double | null), `kay` `"g"` GPS / `"a"` ağ, `sahte` (bool), `zayif` (bool).

Olay (map): `q` sıra, `z` cihaz saati ms, `tur` (aşağıdaki listeden), `a` kısa ayrıntı (string ≤ 80, isteğe bağlı).
`tur`: `hizmet_basladi`, `acilis`, `kapanis`, `konum_kapandi`, `konum_acildi`, `izin_yok`,
`pil_dusuk`, `saat_degisti`, `sahte_konum`, `takip_acildi`, `takip_kapandi`, `kuyruk_tasti`.

**`rotaSonDurum/{uid}`** — terminal oluşturur ve günceller (canlı harita bunu dinler)

`s`, `z` (son nokta GPS zamanı ms), `en`, `boy`, `dog`, `hiz`, `yon`, `pil`, `sarj`,
`durum` (`hareket` | `durgun` | `depoda` | `kapali` | `izin_yok` | `konum_kapali`),
`bekleyen` (kuyrukta gönderilmeyi bekleyen nokta sayısı), `surum`, `guncelleme == request.time`.

### 4.2 Merkezin yazdıkları (yalnız Google girişli rota yöneticisi)

- **`rotaCihazlar/{uid}`**: `ad` (ör. "Terminal 3"), `takip` (bool), `hareketSn`, `durgunSn`,
  `depoSn` (int, 5–3600), `olusturma`, `guncelleme == request.time`, `guncelleyen == auth.uid`.
  Terminal yalnız **kendi** belgesini okur.
- **`rotaAraclar/{aracId}`**: `no`, `plasiyer`, `renk`, `yakit` (`dizel` | `benzin` | `lpg`),
  `tuketim` (L/100 km), `aktif`, `guncelleme`.
- **`rotaAtamalar/{id}`** (yalnız eklenir): `cihaz`, `arac`, `bas` (geçerlilik başlangıcı),
  `yazan`, `zaman`. Bir terminalin belli bir andaki aracı = o andan önceki en son atama.
  Yanlış atama silinmez; daha geç `zaman`lı düzeltme atamasıyla geçersiz kılınır (denetim izi).
- **`rotaAyar/genel`**: `depolar` (liste: `ad`, `en`, `boy`, `yaricap` m), `bolgeler` (il adları).
  Terminaller okur (depoda sıklığı için).
- **`rotaYetkileri/{uid}`**: `eposta`, `ad`, `rol` (`yonetici` | `izleyici`), `aktif`.
  İlk rota yöneticisi yönetici aracıyla (admin SDK) açılır; sonrakileri rota yöneticisi ekler,
  ama **yönetici rolü veremez** ve kendi kaydını değiştiremez.
- **`rotaDenetim/{otomatik}`** (yalnız eklenir): `yazan`, `eylem`, `hedef`, `zaman == request.time`.
  Takip aç/kapa, onay, atama, yetki her değişiklik bununla aynı toplu yazmada olmalıdır.

### 4.3 Okuma yetkisi özeti

| Belge | Terminal (anonim) | Rota izleyici | Rota yöneticisi | Sanal POS kullanıcıları |
|-------|-------------------|---------------|-----------------|-------------------------|
| rotaBasvurular | yalnız kendi oluşturur | — | okur, siler | — |
| rotaCihazlar | kendi belgesini okur | okur | okur/yazar | — |
| rotaParcalar | kendi parçasını **get** (M6) | okur | okur, 90+ gün silebilir | — |
| rotaSonDurum | kendi yazar | okur | okur | — |
| rotaAraclar, rotaAtamalar | — | okur | okur/ekler | — |
| rotaAyar | okur | okur | yazar | — |
| rotaYetkileri | — | kendi kaydını | okur, izleyici ekler | — |

Terminal yazabilmek için `rotaCihazlar/{uid}` belgesinin **var olması** (onaylanmış olması)
gerekir; `takip == false` iken de parça yazabilir (yalnız olaylar: "takip kapandı" gibi).

## 5. Terminal davranışı

**Başlatma.** Uygulama açıldığında, `BOOT_COMPLETED` ve `MY_PACKAGE_REPLACED` sonrasında
`RotaHizmeti` başlatılır. Konum izni yoksa hizmet konum almadan durumu `izin_yok` olarak bildirir
ve olay yazar (izin yokken ön plan konum hizmeti başlatılamaz: yalnız durum gönderilir ve biter;
izin verilince yeniden başlar).

**Kimlik.** "rota" FirebaseApp'inde anonim oturum yoksa açılır, yoksa olan kullanılır.
`rotaCihazlar/{uid}` yoksa `rotaBasvurular/{uid}` bir kez yazılır ve onay beklenir.

**Döngü.**
1. Konum gelir → `OrneklemePolitikasi` noktayı değerlendirir (hareket/durgun/depoda) → SQLite'a
   sıra numarasıyla yazılır (yazılmadan bellekte tutulan nokta yoktur).
2. Politika sıklığın değişmesini isterse LocationManager isteği yeni aralıkla yenilenir.
3. `Gonderici` her 60 sn'de (ağ varsa) kuyruğun başından en çok 240 nokta + bekleyen olayları
   alır, parça olarak yazar; başarıda kuyruktan siler. Ardından `rotaSonDurum` güncellenir.
4. Belirsiz hata (zaman aşımı, ağ): aynı parça kimliğiyle yeniden denenir. `PERMISSION_DENIED`
   alınırsa parça okunur: varsa ve sıraları aynıysa gönderilmiş sayılır; yoksa (ör. onay
   kaldırılmış) kuyrukta kalır, geri çekilme süresiyle (1→2→4… en çok 15 dk) denenir.
5. Kuyruk sınırı: 200.000 nokta (~1 ay çevrimdışı). Aşılırsa en eski noktalar silinir ve
   `kuyruk_tasti` olayı yazılır (sessiz kayıp yok).

**Merkez dinleme.** `rotaCihazlar/{uid}` anlık dinlenir. `takip` değişince GPS açılır/kapanır,
olay yazılır. Sıklık ayarları politikaya aktarılır. Belge silinirse (onay kaldırıldı) takip durur.

**Olay izleme.** `PROVIDERS_CHANGED` (konum aç/kapa), `ACTION_SHUTDOWN`, `BOOT_COMPLETED`,
`BATTERY_LOW`, `TIME_SET` yayınları; her konumda `isMock` (API 31+) / `isFromMockProvider`.
Uçak kipi doğrudan kayıt değildir; veri kesintisi ve olaylar CAL_bup'ta uyarıya dönüşür.

## 6. Güvenlik tehdit tablosu

| Tehdit | Önlem |
|--------|-------|
| Terminaldeki Ali oturumuyla rota verisi okuma/takibi kapatma | M4: rota yetkisi yalnız Google girişli `rotaYetkileri` kaydı |
| Bir terminalin başka terminal adına yazması | Parça kimliği ve `cihaz` alanı `request.auth.uid`'e bağlı |
| API anahtarıyla rastgele anonim hesap açıp yazma | Onaylanmamış uid hiçbir şey yazamaz (yalnız tek başvuru) |
| Eski kaydı değiştirme/silme | Parçalar değiştirilemez; silme yalnız 90+ gün ve yönetici |
| Cihaz saatini oynatma | GPS zamanı + sunucu alım zamanı; fark uyarısı (CAL_bup) |
| Sahte konum uygulaması | Android `isMock` işareti noktada saklanır, uyarı |
| Kötü niyetli içerikle CAL_bup'a saldırı | M14: okuyucu doğrular, HTML basmaz; kural alan/uzunluk sınırları |
| Kotanın aşırı yazmayla tüketilmesi | Parça başına 240 nokta sınırı; cihaz başına gönderim aralığı istemcide; CAL_bup'ta yazma hızı uyarısı |
| Kayıp/çalınan terminal | Merkezden onay kaldırılır (belge silinir) → terminal yazamaz |

## 7. Test stratejisi

| Katman | Araç | Kapsam |
|--------|------|--------|
| Firestore kuralları | `tools/sunucu-test/rota_kurallar.test.mjs` (emülatör) | her belge × her rol, şema sınırları, yalnız ekleme, M6 yeniden okuma |
| Saf Kotlin | JVM birim testi (`android/app/src/test`) | sıklık politikası, parça oluşturma, kod türetme, geri çekilme, sözleşme JSON'u |
| Android | `androidTest` (yalnız emülatör) | SQLite kuyruğu (yeniden açılınca kayıp yok), hizmetin emülatör konumuyla çalışması, Firestore emülatörüne parça yazımı |
| Sözleşme | `docs/rota/sozlesme/*.json` | Kotlin'in ürettiği parça = örnek; CAL_bup okuyucusu aynı örnekleri okur |
| Gerçek cihaz | Ali'nin telefonu (Aşama 1 sonu), sonra TC15 | 24 saat pil/kesinti/birikme ölçümü; elle |

## 8. Aşama 1 iş listesi (sıralı)

1. Bu belge + `ROUTE_PLANI.md` kararları.
2. Firestore kuralları (`rota*`) + emülatör testleri.
3. Saf Kotlin çekirdeği (politika, parça, kod, geri çekilme) + JVM testleri + sözleşme örnekleri.
4. SQLite kuyruğu + emülatör testi.
5. RotaHizmeti, konum kaynağı, olay izleyici, merkez dinleyici, gönderici; manifest izinleri.
6. Gizli "Konum kurulumu" bölümü (Flutter, parola yeniden sorulur) + MethodChannel.
7. Uçtan uca emülatör testi: emülatör konumu → kuyruk → Firestore emülatörü → kurala uygun parça.
8. Yönetici aracı: ilk rota yöneticisi, başvuru onayı (CAL_bup Rota sekmesi gelene kadar).
9. Ali'nin telefonunda 24 saat deneme (Ali'nin onayıyla; canlı kurallar ve Anonymous/Google
   sağlayıcıları açılmadan önce ayrıca sorulur).

## 9. Kota hesabı (Spark: günde 20.000 yazma, 50.000 okuma)

- Yazma: parça en sık 60 sn'de bir → 6 terminal × 1.440 = 8.640 + aynı sayıda `rotaSonDurum`
  = **17.280/gün en kötü durum** (24 saat sürekli hareket). Sınırın altında ama dar. Önlem:
  durgun/depodayken parça 5 dk'da bir; gerçek kullanımda beklenen **~6.000–9.000/gün**.
  CAL_bup'ta günlük yazma sayacı görünür; gerekirse gönderim aralığı merkezden büyütülür.
- Okuma: canlı harita her `rotaSonDurum` değişiminde 1 okuma; yalnız sekme görünürken dinlenir.
- Depolama: nokta ~120 bayt → terminal başına günde ~0,7 MB, 90 günde 6 terminal ~400 MB (< 1 GB).

## 10. Doğrulanması gerekenler (varsayılmaz)

- Firestore TTL'in Spark planında çalışması (M15).
- Android 13/15'te `BOOT_COMPLETED` sonrası konum türü ön plan hizmetinin başlatılabilmesi.
- TC15'te 24 saat GPS'in pil tüketimi (Aşama 1 sonu, gerçek ölçüm).
- Anonymous ve Google sağlayıcılarının canlı projede açılması (Ali'nin onayıyla).
