"""Yalnız bu projenin herkese açık Firebase istemci ayarlarını yeniden oluşturur."""
import json
import subprocess
from pathlib import Path

proje = 'bup-sanal-pos-izmir'
app = '1:1033835683669:web:4e00297e92c9c2f12899dc'
sonuc = subprocess.run(['firebase', 'apps:sdkconfig', 'WEB', app, '--project', proje, '--json'],
                       check=True, capture_output=True, text=True)
d = json.loads(sonuc.stdout)['result']['sdkConfig']
assert d['projectId'] == proje
alanlar = {'apiKey': 'FIREBASE_API_KEY', 'appId': 'FIREBASE_APP_ID',
           'projectId': 'FIREBASE_PROJECT_ID', 'authDomain': 'FIREBASE_AUTH_DOMAIN',
           'messagingSenderId': 'FIREBASE_SENDER_ID'}
ayar = {hedef: d[kaynak] for kaynak, hedef in alanlar.items()}
ayar['BUP_DENEME'] = 'false'
kok = Path(__file__).resolve().parents[1] / 'config'
kok.mkdir(exist_ok=True)
(kok / 'canli.json').write_text(json.dumps(ayar, indent=2) + '\n')
print('Bu projenin istemci ayarları hazır. Hizmet hesabı/parola içermez.')
