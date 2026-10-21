#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
node tools/sunucu-test/yayin_oncesi.mjs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
bash tools/derle.sh canli
firebase deploy --only firestore:rules,firestore:indexes,hosting --project bup-sanal-pos-izmir
