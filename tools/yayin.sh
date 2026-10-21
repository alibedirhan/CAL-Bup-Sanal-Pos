#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
node tools/sunucu-test/yayin_oncesi.mjs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
bash tools/derle.sh canli
# Kart doldurma: kurulum yer imi ve doldur sayfası yalnız gerçek kökenleri taşır.
python3 - <<'KONTROL'
import re
from pathlib import Path
for ad in ('kurulum.js', 'doldur_sayfasi.js'):
    s = Path('build/canli', ad).read_text()
    assert '127.0.0.1' not in s and not re.search(r'__[A-Z_]+__', s), f'{ad}: test kökeni/yer tutucu kaldı'
d = Path('build/canli/doldur_sayfasi.js').read_text()
assert "const POS = 'https://denizpay.bupilic.com.tr';" in d, 'Doldur sayfasında canlı POS kökeni yok'
k = Path('build/canli/kurulum.js').read_text()
assert 'denizpay.bupilic.com.tr' in k and 'bup-sanal-pos-izmir.web.app' in k, 'Kurulum yer iminde canlı kökenler yok'
KONTROL
firebase deploy --only firestore:rules,firestore:indexes,hosting --project bup-sanal-pos-izmir
