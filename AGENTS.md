# BUP Sanal POS — devam bağlamı

Önce `docs/OTURUM_NOTU.md`, ardından `docs/MIMARI.md` okuyun.

- Ayrı Flutter projesidir. CAL bup ve Sipariş uygulamasına bağımlı değildir.
- Kullanıcı kararları: bağlantıdan açılan ve ana ekrana eklenen web sürümü
  (21 Ekim, 0.7.2: ana ekran simgesi Safari/Chrome içinde açılır — manifest
  `display: browser`, `*-web-app-capable` yok; iPhone'da ayrı depolu uygulama
  "BUP Doldur"u bozar, geri almayın);
  herkes yalnız kendisine atanmış carileri görür; CAL bup kayıtlarından bağımsız.
- Kullanıcı yazılımcı değil; Türkçe, kısa ve somut sonuçlarla iletişim kurun.
- 0.2.0'da Firebase giriş/kalıcı kayıt/yönetim kodu eklendi. Deneme kipi hâlâ
  yalnız sentetik ve bellektedir. Canlı Authentication ilk kurulumu, yönetici
  açılışı ve Hosting yayın durumunu OTURUM_NOTU'ndan kontrol edin; varsaymayın.
- 0.3.0 kullanıcı kararı: cari kodu ekranda/formda yoktur; cari adı ve VKN/TC
  alınır. Yeni girişte VKN/TC zorunlu (10/11 rakam). Eski kod alanı yalnız
  mevcut sunucu şeması ve rezervasyon uyumluluğu içindir; gerçek kayıtları
  yeniden yazmayın. POS şifresi, kullanıcının bildirdiği ilk iki + son iki
  hane kuralıyla yalnız açık kopyalama isteğinde hesaplanır; ayrıca saklanmaz.
- POS otomasyonu tamamlanmış değildir. 0.6.0 kullanıcı kararıyla (21 Ekim)
  "DenizPay'e giriş yap" düğmesi seçili carinin VKN/TC + kural şifresini
  `web/pos_giris.js` ile sabit login.aspx adresine form POST'uyla gönderir;
  CSP `form-action` yalnız https://denizpay.bupilic.com.tr. Boş giriş bağlantısı
  yedek olarak durur; kart seçmeden de çalışır (0.7.0). 0.7.0'da Aşama 2:
  "BUP Doldur" yer imi DenizPay kart sayfasına numara/ad/SKT yazar; ayrıntı ve
  güvenlik kuralları `docs/MIMARI.md` "DenizPay girişi ve kart doldurma".
  Plan `docs/MOBIL_DOLDURMA_PLANI.md`. Testi `npm run test:doldur`.
- 0.9.0 (22 Ekim) tahsilat kaydı + gün sonu: DenizPay sonuç ekranında "BUP
  Doldur" (yer imi 2) → `sonuc.html` → telefondaki sonuç kutusu → oturumu açık
  Sanal POS sekmesi `posIslemleri`'ne yazar. Kayıtlar yalnız eklenir; gün Türkiye
  saatiyle 00:00'da kapanır. SESSION oturum kararını değiştirmeyin; ayrıntı
  `docs/TAHSILAT.md`. Testi `npm run test:tahsilat` (emülatör).
- 0.10.0 (22 Ekim) cari eşleştirme: telefonda son 10 giriş tutulur; yer imi 3
  kart sayfasındaki firma VKN'sini DenizPay sekmesine not eder; sonuç sayfası
  cariyi firma numarasıyla belirler, kesin değilse kişiye seçtirir. Eşleşme
  türü (`eslesme`) ve telefon okunma anı (`okunma`) kayda denetim izi olarak
  girer. Sonuç ekranında aynı satır/tablo düzenleri de okunur. JS birim testi
  `npm run test:saf`. Kayıtlar yine değiştirilemez.
- 0.10.1 (23 Ekim): işlem kimliği başarılıda Pos Sipariş No, başarısızda
  sonuna `-h` (Dart `belgeKimligi`, JS `sonuc_kutusu.js kimlik`, kural aynı;
  kural ve hosting birlikte yayınlanır). Sonuç kutudan yalnız sunucuda kayıt
  görülünce çıkar; görünmez işaretler okunan değerden atılır. İptal/düzeltme
  düzeni kullanıcı kararıyla yoktur. Ayrıntı `docs/TAHSILAT.md`.
- **27 Ekim: Android uygulaması** (kullanıcı kararı; 21 Ekim "yerel uygulama
  yok" kararını Android için kaldırır, iPhone web'de kalır). Önce
  `docs/ANDROID_PLANI.md` okuyun: kararlar (kişisel telefon, parmak izi + şifre,
  düğmeyle doldurma, Play'siz APK), aşamalar ve durum. Platform bağdaştırıcıları
  yalnız `lib/bilesim/` üzerinden seçilir (mimari test zorlar). Sürüm imza
  anahtarı depo dışı `~/.bup-sanal-pos/imza/`; asla depoya/CI'a koymayın,
  kaybı güncellemeyi imkânsız kılar. Paket adı `com.bup.sanalpos` değişmez.
  Android testleri yalnız emülatörde: `bash tools/android_test.sh emulator-NNNN`
  (gerçek telefona kurmayın; kullanıcının telefonu USB'de bağlı olabilir).
  Kart kasası kuralları `lib/data/kasa/` (web JS ile aynı sözleşme).
- Yalnız yeni `bup-sanal-pos-izmir` Firebase projesi kullanılır. Billing kapalı
  kalır. CAL bup / Sipariş Firebase projesine veya verisine yazmayın.
- Gerçek POS'a istek, giriş, kart/ödeme/SMS testi yapmayın. Gerçek şirket,
  müşteri, kart, parola veya başka projenin yapılandırmasını kopyalamayın.
- 18 Ekim kullanıcı yeni kararı: tam kart numarası yalnız eklenen cihazda
  şifreli saklanacak; ikinci kasa parolası istenmiyor. Cloud'da yalnız kart
  özeti ve opak yerel kayıt referansı kalır; PAN/kart sahibi/telefon buluta
  gitmez. CVV/OTP toplanmaz/saklanmaz. Bu karar önceki PAN formu yasağının
  yalnız cihazdaki tam numara için açık istisnasıdır. Canlı kart işlemi
  sağlayıcının belgelenmiş güvenli akışına bağlıdır; mevcut masaüstü eklentisini
  mobilde çalışacakmış gibi sunmayın.
- `domain` ve `application` Flutter/platform/SDK bilmez. `ui` somut depoya
  bağlanmaz. Bileşim `app.dart` içindedir. Dosyalar en fazla 400 satır.
- GitHub: özel depo `origin` (alibedirhan/CAL-Bup-Sanal-Pos); her işten sonra
  commit + push. `.github/workflows/kontrol.yml` her gönderimde testleri koşar.
- Anlamlı davranış değişikliklerini sentetik testlerle doğrulayın.
  `bash tools/kontrol.sh` ve derlenmiş paket üzerinde `npm test`
  (`tools/tarayici/`) çalıştırın. Tarayıcı testi için önizleme sunucusu gerekir.
- Ekran görüntüleri ve günlükler `/tmp/` altında; kaynak deposuna girmez.
- Emülatör `demo-bup-pos`, 8088/9098; tarayıcı 4197'de çalışır.
  Testleri gerçek hesaplarla/sağlayıcıyla çalıştırmayın.
- Canlı tarayıcı paketi `build/canli`, demo `build/web`, emülatör `build/emulator`.
  Yayın öncesi Firebase Auth, en az 6 karakter sunucu şifre politikası ve
  billing kapalı koşulu `tools/sunucu-test/yayin_oncesi.mjs` ile zorlanır.
- Mevcut CAL bup, Sipariş, masaüstü kaynak ve tasarım örneklerini koruyun.
- Gerçek telefon, TalkBack/VoiceOver, kurulum, sunucu yetkilendirmesi ve ödeme
  kabulü yapılmadıysa otomatik test sonuçlarından bunları çıkarmayın.
