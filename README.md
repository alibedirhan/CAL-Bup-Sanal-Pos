# BUP Sanal POS

Ayrı Flutter uygulaması. Android ve iPhone için bağlantıdan açılan, ana ekrana
eklenebilen web sürümü hedeflenir. CAL bup kayıtlarından bağımsızdır.

Uygulama: **https://bup-sanal-pos-izmir.web.app/**
İlk yönetici hesabı açılmıştır. Kullanıcı giriş ekranına kendi e-posta adresini
yazıp “Şifremi unuttum” ile şifresini kendisi belirler (en az 6 karakter).
Kullanıcı yönetimi ve cari atamaları girişten sonra çalışma alanındadır.

**0.4.1:** e-posta/şifre girişi, kalıcı cari ve kart özetleri, kullanıcı yönetimi,
cari atama ve sunucuda erişim kuralları var. Cari kodu istenmez; cari adı ve
VKN/TC ile kayıt açılır. Sunucuda onaylanmış kayıt, sonraki okuma gecikmesi
nedeniyle başarısız gösterilmez. Canlı kurulum/yayın durumu
[oturum notunun](docs/OTURUM_NOTU.md) en üstündedir; sadece kaynak dosyalarının
bulunması canlı sistemin açıldığı anlamına gelmez.

Ödeme düğmesi doğrudan `https://denizpay.bupilic.com.tr/login.aspx`
adresini telefonun tarayıcısında yeni sekmede açar. URL ile bilgi taşınmaz. **Seçili kartı otomatik aktarma henüz tamamlanmadı.**
Tam kart numarası, kart üzerindeki ad ve iletişim telefonu yalnız eklendiği
tarayıcıda AES-GCM ile şifreli saklanır; ek kasa parolası istenmez. Firebase'e
yalnız kart adı/son dört hane/tarih ve opak yerel kayıt referansı gider.
**Tarayıcı verileri silinirse tam bilgiler kaybolur; başka cihazda yalnız özet
görünür. CVV kaydedilmez.** Cariyi açıp “Kart ekle” ile ekleyebilir,
“Bilgiler / düzenle” ile bu tarayıcıdaki bilgiyi açabilirsin.
Ayrıntı [cihaz kart kasası](docs/CIHAZ_KART_KASASI.md). Kullanıcının bildirdiği POS şifresi
kuralı (VKN/TC ilk iki + son iki hane) yalnız “POS şifresini kopyala” isteğinde
hesaplanır; şifre ayrıca saklanmaz. Ayrıntı [POS kararı](docs/POS_KARARI.md).

## Deneme önizlemesi

Flutter 3.41.2 / Dart 3.11.0. Test araçları için Node 22 ve Java 21.

```sh
flutter pub get
bash tools/kontrol.sh
python3 tools/sunucu.py
```

`http://127.0.0.1:4195` → Denemeyi aç. Demo yapay verili ve bellektedir;
yenilemede sıfırlanır. Bu yerel adres telefondan açılmaz. Telefon için HTTPS
yayını ve fiziksel cihaz kabulü gerekir; manifest ve ana ekran simgeleri hazır.

## Giriş ve kalıcı kayıt kabulü

```sh
npm --prefix tools/sunucu-test ci
npm --prefix tools/tarayici ci
npx --prefix tools/tarayici playwright install chromium webkit
firebase emulators:start --only auth,firestore --project demo-bup-pos
```

Emülatör açıkken ayrı terminalde:

```sh
npm --prefix tools/sunucu-test test
bash tools/derle.sh emulator
python3 tools/sunucu.py --paket emulator --port 4197
```

4197 açıkken `npm --prefix tools/tarayici run test:hesap`. Sunucu kural testi ve
hesap tarayıcı testi aynı emülatörde **sırayla** çalışır; yalnız yapay verileri
sıfırlarlar. Gerçek Firebase veya gerçek POS üzerinde bu testleri çalıştırmayın.
Demo tarayıcı kabulü: 4195 açıkken `npm --prefix tools/tarayici test`.
Görseller/günlükler `/tmp/` altındadır. Linux WebKit denemesi fiziksel iPhone
veya Safari ana ekran kurulumunun yerine geçmez.

## Canlı kurulum

Yeni kaynaklar yalnız `bup-sanal-pos-izmir` projesindedir. Ücretli plan açılmaz.
İlk Authentication kurulumu Firebase konsolunda tamamlanır. Yerel operatör
araçları ilk yönetici hesabını açar ve kullanıcı şifresini kendisi belirler;
şifre istenmez veya kaynak dosyasına konmaz. Sunucu politikası en az 6 karakterdir.

[Canlı altyapı ve operatör adımları](docs/CANLI_ALTYAPI.md). Yayın kapısı yanlış
proje, demo/emülatör veya billing açık koşulunda durur. `build/canli` canlı,
`build/web` demo, `build/emulator` yerel kabul paketidir.

[Mimari](docs/MIMARI.md) · [Çalışma kuralları](AGENTS.md)
