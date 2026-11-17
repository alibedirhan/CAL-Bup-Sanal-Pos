#!/usr/bin/env bash
# Rota testleri (docs/ROTA_MIMARI.md §7). YALNIZ Android emülatöründe: gerçek telefona kurulmaz.
#
#   bash tools/rota_test.sh emulator-5584
#
# 1. Firestore kuralları + sözleşme (Firebase emülatörü)
# 2. Kotlin birim testleri (JVM)
# 3. Kalıcı kuyruk (emülatörde Android testi)
# 4. Uçtan uca: emülatör yapılandırmasıyla derlenmiş uygulama + Firebase emülatörü + emülatör GPS'i
set -euo pipefail
cd "$(dirname "$0")/.."
cihaz="${1:?Kullanım: bash tools/rota_test.sh emulator-NNNN}"
case "$cihaz" in
  emulator-*) ;;
  *) echo "Yalnız emülatör kabul edilir (gerçek telefona kurulmaz): $cihaz" >&2; exit 1 ;;
esac
adb() { "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" -s "$cihaz" "$@"; }
[ "$(adb shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r')" = "1" ] \
  || [ "$(adb shell getprop ro.boot.qemu 2>/dev/null | tr -d '\r')" = "1" ] \
  || { echo "Cihaz emülatör değil: $cihaz" >&2; exit 1; }

echo '== 1. Kurallar ve sözleşme'
firebase emulators:exec --only firestore --project demo-bup-pos \
  "cd tools/sunucu-test && node --test --test-concurrency=1 rota_kurallar.test.mjs rota_sozlesme.test.mjs" \
  > /tmp/rota_kurallar.log 2>&1 || { grep -E '^not ok|error' /tmp/rota_kurallar.log >&2; exit 1; }
grep -E '^# (pass|fail)' /tmp/rota_kurallar.log

echo '== 2. Kotlin birim testleri'
(cd android && ./gradlew -q :app:testDebugUnitTest)

echo '== 3. Kalıcı kuyruk (emülatör)'
(cd android && ./gradlew -q :app:assembleDebug :app:assembleDebugAndroidTest)
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk >/dev/null
adb install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk >/dev/null
cikti="$(adb shell am instrument -w -e class com.bup.sanalpos.rota.NoktaKuyruguTest com.bup.sanalpos.test/androidx.test.runner.AndroidJUnitRunner)"
echo "$cikti" | tail -1
echo "$cikti" | grep -q '^OK (' || { echo 'Kuyruk testleri başarısız' >&2; exit 1; }

echo '== 4. Uçtan uca'
flutter build apk --debug --no-pub --dart-define-from-file=config/emulator_android.json >/dev/null
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk >/dev/null
firebase emulators:exec --only auth,firestore --project demo-bup-pos \
  "node tools/sunucu-test/rota_uctan_uca.mjs $cihaz"
