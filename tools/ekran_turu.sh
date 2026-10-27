#!/usr/bin/env bash
# Arayüz gözden geçirme: emülatörü Zebra TC15 boyutuna (720x1600, 320 dpi)
# ayarlar, integration_test/android_ekran_turu_test.dart'ı çalıştırır, her
# "EKRAN:<ad>" satırında ekran görüntüsü alır. YALNIZ emülatör; boyut sonunda
# geri alınır. Görüntüler depo dışına: bash tools/ekran_turu.sh emulator-NNNN <klasör>
set -euo pipefail
cd "$(dirname "$0")/.."
cihaz="${1:?Kullanım: bash tools/ekran_turu.sh emulator-NNNN <klasör>}"
klasor="${2:?Görüntü klasörü (depo dışı)}"
case "$cihaz" in emulator-*) ;; *) echo "Yalnız emülatör: $cihaz" >&2; exit 1 ;; esac
adb() { "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" -s "$cihaz" "$@"; }
mkdir -p "$klasor"
adb shell wm size 720x1600
adb shell wm density 320
trap 'adb shell wm size reset; adb shell wm density reset' EXIT
adb_yolu="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb -s $cihaz"
firebase emulators:exec --only auth,firestore --project demo-bup-pos \
  "node tools/sunucu-test/android_hazirla.mjs && ($adb_yolu shell pm clear com.bup.sanalpos >/dev/null 2>&1 || true) \
   && flutter test integration_test/android_ekran_turu_test.dart -d $cihaz --no-pub --dart-define-from-file=config/emulator_android.json" \
  2>&1 | while IFS= read -r satir; do
    echo "$satir"
    if [[ "$satir" =~ EKRAN:([0-9a-z_]+) ]]; then
      adb exec-out screencap -p > "$klasor/${BASH_REMATCH[1]}.png"
    fi
  done
