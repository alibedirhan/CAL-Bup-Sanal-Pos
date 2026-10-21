"""Sadece build/web klasörünü, yalnız bu bilgisayarda önizler."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=4195)
parser.add_argument('--paket', choices=['web', 'emulator', 'canli'], default='web')
args = parser.parse_args()
kok = Path(__file__).resolve().parents[1] / 'build' / args.paket
if not (kok / 'index.html').is_file():
    raise SystemExit('Önce bash tools/kontrol.sh çalıştırın.')


class Onizleme(SimpleHTTPRequestHandler):
    def list_directory(self, path):
        self.send_error(404)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
        self.send_header('Content-Security-Policy',
                         "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com https://apis.google.com; "
                         "style-src 'self' 'unsafe-inline'; font-src 'self' data:; "
                         "img-src 'self' data: blob:; connect-src 'self' https://www.gstatic.com "
                         "https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://firestore.googleapis.com "
                         "http://127.0.0.1:8088 http://127.0.0.1:9098 ws://127.0.0.1:8088; "
                         "worker-src 'self' blob:; frame-src 'self' https://bup-sanal-pos-izmir.firebaseapp.com; "
                         "frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action https://denizpay.bupilic.com.tr")
        super().end_headers()


print(f'Önizleme: http://127.0.0.1:{args.port}', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), partial(Onizleme, directory=str(kok))).serve_forever()
