#!/usr/bin/env bash
# Android testleri (docs/ANDROID_PLANI.md). YALNIZ Android emülatöründe çalışır:
# gerçek telefona hiçbir şey kurulmaz. Firebase emülatörü (demo-bup-pos) ve
# yapay veriler kullanılır; gerçek Firebase, DenizPay veya kart kullanılmaz.
#
#   bash tools/android_test.sh emulator-5584
#
# 1. Kotlin Keystore testleri (ekran kilidi PIN'i geçici olarak açılır ve
#    telefon PIN'le açılır: anahtar yalnız kilit açıkken kullanılır)
# 2. Telefon kilitliyken anahtarın kullanılamadığı
# 3. Ekran kilidi yokken: telefon kilidi anahtarı kullanılmaz, kasa uygulama
#    PIN'iyle korunur (PIN kaldırılır)
# 4. Uçtan uca uygulama testleri (giriş, cari, kart kasası, kilit, DenizPay,
#    sürüm denetimi; son olarak ekran kilidi kaldırılıp uygulama PIN'i)
set -euo pipefail
cd "$(dirname "$0")/.."
cihaz="${1:?Kullanım: bash tools/android_test.sh emulator-NNNN}"
case "$cihaz" in
  emulator-*) ;;
  *) echo "Yalnız emülatör kabul edilir (gerçek telefona kurulmaz): $cihaz" >&2; exit 1 ;;
esac
adb() { "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" -s "$cihaz" "$@"; }
[ "$(adb shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r')" = "1" ] \
  || [ "$(adb shell getprop ro.boot.qemu 2>/dev/null | tr -d '\r')" = "1" ] \
  || { echo "Cihaz emülatör değil: $cihaz" >&2; exit 1; }

PIN=1357
# Emülatörün giriş hizmeti ara sıra geçici hata verir ("Broken pipe"): yeniden dene.
girdi() {
  for _ in 1 2 3 4 5; do adb shell input "$@" && return 0; sleep 1; done
  echo "Emülatöre giriş gönderilemedi: $*" >&2
  return 1
}
kilit_gorunuyor() { adb shell dumpsys window | grep -q 'isKeyguardShowing=true'; }
# Gerçek kullanımdaki gibi: telefon kilitlenir ve PIN'le açılır.
kilitle() { girdi keyevent KEYCODE_SLEEP; sleep 2; }
kilidi_ac() {
  girdi keyevent KEYCODE_WAKEUP; sleep 1
  adb shell wm dismiss-keyguard || true; sleep 1
  if kilit_gorunuyor; then
    girdi text "$PIN"; girdi keyevent KEYCODE_ENTER; sleep 2
  fi
  ! kilit_gorunuyor || { echo 'Emülatörün kilidi açılamadı' >&2; return 1; }
}
pin_kaldir() { adb shell locksettings clear --old "$PIN" >/dev/null 2>&1 || true; }
pin_ayarla() {
  pin_kaldir
  adb shell locksettings set-pin "$PIN" | grep -q "Pin set" \
    && adb shell locksettings verify --old "$PIN" | grep -q "verified successfully" \
    || { echo 'Emülatörde ekran kilidi PIN’i ayarlanamadı' >&2; exit 1; }
  kilitle
  kilidi_ac
}
calistir() {
  local cikti
  cikti="$(adb shell am instrument -w "$@" com.bup.sanalpos.test/androidx.test.runner.AndroidJUnitRunner)"
  echo "$cikti" | tail -3
  echo "$cikti" | grep -q '^OK (' || { echo 'Kotlin testleri başarısız' >&2; exit 1; }
}
trap pin_kaldir EXIT

adb shell svc power stayon true
kilidi_ac

echo '== Kotlin Keystore testleri'
(cd android && ./gradlew -q :app:assembleDebug :app:assembleDebugAndroidTest)
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk >/dev/null
adb install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk >/dev/null
pin_ayarla
calistir -e class com.bup.sanalpos.KasaAnahtariTest,com.bup.sanalpos.GuvenlikKanaliTest

echo '== Telefon kilitliyken'
calistir -e class com.bup.sanalpos.KilitliTelefonTest#hazirla
kilitle
calistir -e class com.bup.sanalpos.KilitliTelefonTest#kilitliyken
kilidi_ac

echo '== Ekran kilidi yokken'
pin_kaldir
calistir -e class com.bup.sanalpos.EkranKilidiYokTest,com.bup.sanalpos.PinKasasiTest

echo '== Uçtan uca (Firebase emülatörü + taklit DenizPay)'
pin_ayarla
python3 tools/android_taklit_denizpay.py & taklit=$!
trap 'kill $taklit 2>/dev/null; pin_kaldir' EXIT
for _ in $(seq 1 20); do curl -s -o /dev/null http://127.0.0.1:4199/girisler && break; sleep 0.5; done
adb_yolu="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb -s $cihaz"
tanim="--dart-define-from-file=config/emulator_android.json"
# Her test temiz uygulama verisiyle başlar ("flutter test" bitince uygulamayı
# kaldırabilir; o zaman temizlenecek veri yoktur).
temizle="($adb_yolu shell pm clear com.bup.sanalpos >/dev/null 2>&1 || true)"
# Kamera izni sistem penceresiyle istenir; testte adb ile verilir. "flutter test"
# uygulamayı yeniden kurabildiği için izin uçtan uca testler boyunca 2 sn'de bir
# yinelenir (aynı izni yeniden vermek etkisizdir; yalnız emülatör). "set -e"
# altında döngü ilk hatada (uygulama henüz kurulu değil) ölmesin: "|| true".
( while true; do adb shell pm grant com.bup.sanalpos android.permission.CAMERA >/dev/null 2>&1 || true; sleep 2; done ) & izinci=$!
trap 'kill $taklit $izinci 2>/dev/null; pin_kaldir' EXIT
firebase emulators:exec --only auth,firestore --project demo-bup-pos \
  "node tools/sunucu-test/android_hazirla.mjs \
   && $temizle && flutter test integration_test/android_akis_test.dart -d $cihaz --no-pub $tanim \
   && $temizle && flutter test integration_test/android_denizpay_test.dart -d $cihaz --no-pub $tanim \
   && $temizle && flutter test integration_test/android_surum_test.dart -d $cihaz --no-pub $tanim \
   && $temizle && flutter test integration_test/android_kamera_test.dart -d $cihaz --no-pub $tanim \
   && ($adb_yolu shell locksettings clear --old $PIN >/dev/null) \
   && $temizle && flutter test integration_test/android_pin_test.dart -d $cihaz --no-pub $tanim"
