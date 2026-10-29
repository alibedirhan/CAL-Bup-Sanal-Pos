# Aşama 4 — gerçek cihaz kabulü (Zebra TC15)

Cihaz: Zebra TC15, Android 13, ekran kilidi yok, parmak izi yok (27 Ekim 2026).
**Cihaz kullanıcıya emanettir:** bilgisayardan yalnız okuma yapılır (sürüm,
günlük); kurma/silme/ayar değişikliği yapılmaz. Bütün adımları kullanıcı kendi
eliyle yapar. Uygulamayı kaldırmak, verilerini silmek ve 10 kez yanlış PIN
denemek kabul listesinde YOKTUR (kartları siler).

Durum: ✅ geçti · ❌ sorun (not) · ⏳ yapılmadı · — uygulanamaz

## A. Kurulum ve güncelleme
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| A1 | 0.11.0 → 0.11.1 uygulama içi notla güncelle | Üstüne kurulur, veriler kalır | ✅ 27 Ekim (versionCode 20, ilk kurulum zamanı aynı) |
| A2 | 0.11.1 → 0.12.0 aynı yolla | Not görünür, üstüne kurulur, giriş/cariler yerinde | ⏳ |

## B. Giriş ve kilit
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| B1 | Şirket e-postası + şifreyle giriş | Cariler listesi | ⏳ |
| B2 | Sağ üstteki kilit → şifreyle aç | Aynı ekrana döner | ⏳ |
| B3 | Uygulamayı kapatıp yeniden aç | Şifre sorulur (bu cihazda parmak izi yok) | ⏳ |
| B4 | 5 dk'dan uzun başka uygulamada kal, dön | Kilitli, şifre ister | ⏳ |

## C. Kart ve uygulama PIN'i
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| C1 | Bir cariye ilk kartı ekle | "Uygulama PIN'i belirle"; 123456 reddedilir; geçerli PIN kabul | ⏳ |
| C2 | Kartı "Bilgiler / düzenle" ile aç | Bu oturumda PIN sorulmaz, numara doğru | ⏳ |
| C3 | Kilitle, aç, kartı yeniden aç | PIN sorulur; bir kez yanlış → "PIN yanlış", doğru → açılır | ⏳ |

## D. Karttan okuma (0.12.0)
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| D1 | Kart ekle → "Temassız oku" → kendi kartını arkaya dokundur | Numara ve son kullanma dolar; ad boş kalabilir; CVV boş | ⏳ |
| D2 | NFC kapalıyken "Temassız oku" | "NFC kapalı" + "Ayarları aç"; açıp dönünce okur | ⏳ |
| D3 | "Kamerayla oku" (ilk sefer izin sorulur → İzin ver) | Numara ve tarih dolar; kart yüzü ekranda | ⏳ |
| D4 | Kabartma/parlak kartta kamera | Okursa doğru okumalı; okuyamazsa elle yazılır | ⏳ |

## E. DenizPay ve tahsilat
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| E1 | Cari → "Ödeme sitesine geç" → onay | DenizPay uygulama içinde, carinin VKN'siyle giriş | ✅ 29 Ekim (0.12.0) |
| E2 | Kart sayfasında "Kartı doldur" (PIN istenebilir) | Numara/ad/SKT dolar; CVV ve tutar boş | ⏳ |
| E3 | Gerçek ödeme (kullanıcının kararıyla, küçük tutar) | 3D Secure/SMS sayfası uygulama içinde açılır | ✅ 29 Ekim (0.12.0; başarılı çekim, sonuç ekranı doğru okundu) |
| E4 | Sonuç ekranı açılınca kayıt kendiliğinden (0.12.1) | "Kaydedildi"; "Gün sonu"nda görünür | ❌ 29 Ekim 0.12.0: düğmeye basılmadı → kayıt yok, elle kaydedildi; düzeltme 0.12.1 (otomatik kayıt), yeniden ⏳ |
| E5 | Aynı kaydı web sürümünde (yönetici) görmek | Gün sonunda aynı satır | ⏳ |
| E6 | Kartsız cari ile DenizPay'e giriş | Giriş olur; kart bilgileri elle | ⏳ |

## F. Güvenlik gözlemleri
| # | Adım | Beklenen | Durum |
|---|------|----------|-------|
| F1 | Uygulamadayken ekran görüntüsü almayı dene | Engellenir | ⏳ |
| F2 | Son uygulamalar listesi | Uygulama önizlemesi boş/gizli | ⏳ |
| F3 | İnternet kapalıyken ödeme sonucu kaydı | "Bekliyor"; internet gelince kaydedilir | ⏳ |

Sonuçlar bu tabloya işlenir; her ❌ için ayrı not ve düzeltme sürümü yazılır.
Bütün satırlar ✅ (veya gerekçeli —) olmadan Android "tamamlandı" denmez.
