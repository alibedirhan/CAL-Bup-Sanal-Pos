#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
kip="${1:-deneme}"
case "$kip" in
  deneme) paket=web; ayar=() ;;
  emulator) paket=emulator; ayar=(--dart-define-from-file=config/emulator.json) ;;
  canli)
    python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path('config/canli.json').read_text())
assert d['FIREBASE_PROJECT_ID']=='bup-sanal-pos-izmir', 'Yanlış proje'
assert d['BUP_DENEME']=='false' and d.get('BUP_EMULATOR','false')=='false', 'Canlı derleme kipi geçersiz'
PY
    paket=canli; ayar=(--dart-define-from-file=config/canli.json) ;;
  *) echo 'Kullanım: bash tools/derle.sh deneme|emulator|canli'; exit 1 ;;
esac
# Flutter artımlı derleme izleri aynı çıktı dizinini bekler. Paketler arasında
# çıktı yolunu değiştirmek önceki paketten font/statik dosyaları silebiliyor.
flutter build web --release --no-pub --no-web-resources-cdn --csp --no-source-maps --no-wasm-dry-run --output=build/derleme "${ayar[@]}"
python3 - "$paket" <<'PY'
import shutil
import sys
from pathlib import Path
paket = sys.argv[1]
assert paket in {'web', 'emulator', 'canli'}
hedef = Path('build') / paket
if hedef.exists():
    shutil.rmtree(hedef)
shutil.copytree('build/derleme', hedef)
PY
python3 tools/web_hazirla.py --paket "$paket"
