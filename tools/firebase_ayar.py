"""Yalnız bu projenin herkese açık Firebase istemci ayarlarını yeniden oluşturur.

config/canli.json: web paketi; config/android.json: Android uygulaması. İkisi de
git dışıdır, hizmet hesabı/parola içermez (istemci ayarı herkese açık değerdir).
"""
import json
import subprocess
from pathlib import Path

proje = 'bup-sanal-pos-izmir'
web = '1:1033835683669:web:4e00297e92c9c2f12899dc'
android = '1:1033835683669:android:bbc86615d73967502899dc'
paket = 'com.bup.sanalpos'


def sdk(platform, app):
    sonuc = subprocess.run(['firebase', 'apps:sdkconfig', platform, app, '--project', proje, '--json'],
                           check=True, capture_output=True, text=True)
    return json.loads(sonuc.stdout)['result']


d = sdk('WEB', web)['sdkConfig']
assert d['projectId'] == proje
alanlar = {'apiKey': 'FIREBASE_API_KEY', 'appId': 'FIREBASE_APP_ID',
           'projectId': 'FIREBASE_PROJECT_ID', 'authDomain': 'FIREBASE_AUTH_DOMAIN',
           'messagingSenderId': 'FIREBASE_SENDER_ID'}
ayar = {hedef: d[kaynak] for kaynak, hedef in alanlar.items()}
ayar['BUP_DENEME'] = 'false'

g = json.loads(sdk('ANDROID', android)['fileContents'])
istemci = [c for c in g['client'] if c['client_info']['mobilesdk_app_id'] == android]
assert g['project_info']['project_id'] == proje and len(istemci) == 1
assert istemci[0]['client_info']['android_client_info']['package_name'] == paket
ayar_android = {
    'FIREBASE_API_KEY': istemci[0]['api_key'][0]['current_key'],
    'FIREBASE_APP_ID': android,
    'FIREBASE_PROJECT_ID': proje,
    'FIREBASE_AUTH_DOMAIN': ayar['FIREBASE_AUTH_DOMAIN'],
    'FIREBASE_SENDER_ID': g['project_info']['project_number'],
    'BUP_DENEME': 'false',
}

kok = Path(__file__).resolve().parents[1] / 'config'
kok.mkdir(exist_ok=True)
(kok / 'canli.json').write_text(json.dumps(ayar, indent=2) + '\n')
(kok / 'android.json').write_text(json.dumps(ayar_android, indent=2) + '\n')
print('Bu projenin web ve Android istemci ayarları hazır. Hizmet hesabı/parola içermez.')
