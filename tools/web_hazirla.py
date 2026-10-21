"""Derleme giriş dosyalarını içerik sürümüyle işaretler; yayın yapmaz."""
import hashlib
import re
import argparse
import sys
import json
from urllib.parse import urlparse, unquote
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--paket', choices=['web', 'emulator', 'canli'], default='web')
args = parser.parse_args()
kok = Path(__file__).resolve().parents[1] / 'build' / args.paket
ana = kok / 'main.dart.js'
surum = hashlib.sha256(ana.read_bytes()).hexdigest()[:16]
bootstrap = kok / 'flutter_bootstrap.js'
metin = bootstrap.read_text()
if 'main.dart.js' not in metin:
    raise SystemExit('Flutter açılış biçimi değişmiş; derleme elle incelenmeli.')
metin = re.sub(r'main\.dart\.js(?:\?v=[a-f0-9]+)?', f'main.dart.js?v={surum}', metin)
bootstrap.write_text(metin)
index = kok / 'index.html'
html = index.read_text()
html = re.sub(r'flutter_bootstrap\.js(?:\?v=[a-f0-9]+)?', f'flutter_bootstrap.js?v={surum}', html)
if args.paket != 'web':
    proje = Path(__file__).resolve().parents[1]
    config = proje / '.dart_tool/package_config.json'
    paketler = json.loads(config.read_text())['packages']
    paket = next(p for p in paketler if p['name'] == 'firebase_core_web')
    uri = urlparse(paket['rootUri'])
    kaynak = Path(unquote(uri.path)) if uri.scheme == 'file' else config.parent / paket['rootUri']
    surum_dart = (kaynak / 'lib/src/firebase_sdk_version.dart').read_text()
    sdk = re.search(r"supportedFirebaseJsSdkVersion = '([0-9.]+)'", surum_dart).group(1)
    js = (proje / 'web/firebase_baslat.js').read_text()
    js = js.replace('__FIREBASE_SDK_VERSION__', sdk).replace('__BOOTSTRAP_URL__', f'flutter_bootstrap.js?v={surum}')
    emulator_setup = ''
    if args.paket == 'emulator':
        d = json.loads((proje / 'config/emulator.json').read_text())
        assert d['FIREBASE_PROJECT_ID'].startswith('demo-')
        alanlar = {'FIREBASE_API_KEY': 'apiKey', 'FIREBASE_APP_ID': 'appId',
                   'FIREBASE_PROJECT_ID': 'projectId', 'FIREBASE_AUTH_DOMAIN': 'authDomain',
                   'FIREBASE_SENDER_ID': 'messagingSenderId'}
        options = json.dumps({hedef: d[kaynak] for kaynak, hedef in alanlar.items()})
        emulator_setup = f'''const app = window.firebase_core.initializeApp({options});
  const auth = window.firebase_auth.initializeAuth(app, {{
    errorMap: window.firebase_auth.debugErrorMap,
    persistence: [window.firebase_auth.indexedDBLocalPersistence, window.firebase_auth.browserLocalPersistence, window.firebase_auth.browserSessionPersistence],
    popupRedirectResolver: window.firebase_auth.browserPopupRedirectResolver
  }});
  window.firebase_auth.connectAuthEmulator(auth, 'http://127.0.0.1:9098', {{disableWarnings: true}});'''
    js = js.replace('__EMULATOR_SETUP__', emulator_setup)
    (kok / 'firebase_baslat.js').write_text(js)
    html = re.sub(r'<script src="flutter_bootstrap\.js[^\"]*" async></script>',
                  f'<script type="module" src="firebase_baslat.js?v={surum}"></script>', html)
index.write_text(html)
# Yer imi sayfaları (deneme, kurulum, doldur): canlıda gerçek kökenler, yerelde yalnız taklit POS kökeni.
sys.path.insert(0, str(Path(__file__).resolve().parent / 'yer_imi'))
from uret import CANLI_POS, CANLI_UYGULAMA, TAKLIT_POS, sayfalar  # noqa: E402
kokenler = {'canli': (CANLI_UYGULAMA, CANLI_POS), 'web': ('http://127.0.0.1:4195', TAKLIT_POS),
            'emulator': ('http://127.0.0.1:4197', TAKLIT_POS)}[args.paket]
for ad, icerik in sayfalar(*kokenler).items():
    (kok / ad).write_text(icerik)
print(f'Web paketi hazır: {surum} (yalnız yerel derleme)')
