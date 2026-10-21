#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
node tools/sunucu-test/yayin_oncesi.mjs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
bash tools/derle.sh canli
# Canlı deneme yer imi yalnız gerçek Sanal POS ve DenizPay kökenlerini taşımalı.
python3 - <<'KONTROL'
from pathlib import Path
t = Path('build/canli/deneme.js').read_text()
assert "const POS = 'https://denizpay.bupilic.com.tr';" in t, 'Canlı POS kökeni yok'
assert "https://bup-sanal-pos-izmir.web.app" in t, 'Uygulama kökeni yok'
assert '127.0.0.1' not in t and '__' not in t.replace('__bupDeneme', ''), 'Test kökeni/yer tutucu kaldı'
KONTROL
firebase deploy --only firestore:rules,firestore:indexes,hosting --project bup-sanal-pos-izmir
