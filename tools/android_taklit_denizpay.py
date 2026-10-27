"""Android uçtan uca testi için taklit DenizPay ve taklit 3D Secure bankası.

Yalnız bilgisayarın yerel adresinde (127.0.0.1) çalışır; Android emülatörü
10.0.2.2 ile ulaşır. Gerçek DenizPay'e veya bankaya istek yoktur; kart, şifre
veya tutar hiçbir yere yazılmaz. Sayfa düzeni web testlerindeki taklitle aynı
(tools/tarayici/doldur-kabul.mjs): "Firma İsmi : … (VKN)", name/number/expiry/
cvc/Tutar kutuları, Onay Formu.

  python3 tools/android_taklit_denizpay.py   # 4199 DenizPay, 4200 banka
"""
import html
import itertools
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

POS, BANKA = 4199, 4200
EMULATOR = '10.0.2.2'
sayac = itertools.count(1)
girisler = []  # yalnız denetim için: (vkn, şifre kuralı tuttu mu)


def sayfa(govde):
    return ('<!doctype html><meta charset="utf-8"><meta name="viewport" '
            'content="width=device-width,initial-scale=1"><title>Yapay DenizPay</title>'
            f'<body style="font:16px sans-serif;padding:12px">{govde}</body>')


def kart_sayfasi(vkn):
    return sayfa(f'''<h3>Ödeme</h3>
<p>Firma İsmi : ÖRNEK YAPAY FİRMA (<a href="#">{html.escape(vkn)}</a>)</p>
<form id="f" method="post" action="http://{EMULATOR}:{BANKA}/3d">
<input name="name" id="name" placeholder="Full Name"><br>
<input name="number" id="number" placeholder="•••• •••• •••• ••••"><br>
<input name="expiry" id="expiry" placeholder="MM/YY"><br>
<input name="cvc" id="cvc" placeholder="CVC"><br>
<input name="Tutar" id="Tutar" placeholder="Tutar"><br>
<button id="ode" type="submit">Öde</button></form>
<p><a id="kotu" href="intent://x#Intent;scheme=https;end">uygulama</a>
<a id="http" href="http://192.168.1.250/">başka</a></p>''')


class Pos(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def gonder(self, kod, govde='', **basliklar):
        veri = govde.encode()
        self.send_response(kod)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(veri)))
        for ad, deger in basliklar.items():
            self.send_header(ad.replace('_', '-'), deger)
        self.end_headers()
        self.wfile.write(veri)

    def oturum(self):
        for parca in (self.headers.get('Cookie') or '').split(';'):
            ad, _, deger = parca.strip().partition('=')
            if ad == 'oturum':
                return deger
        return None

    def do_POST(self):
        uzunluk = int(self.headers.get('Content-Length') or 0)
        alan = {k: v[0] for k, v in parse_qs(self.rfile.read(uzunluk).decode(), keep_blank_values=True).items()}
        if self.path == '/login.aspx':
            vkn = alan.get('lvergino', '')
            dogru = (len(vkn) in (10, 11) and alan.get('lkullaniciadi') == vkn
                     and alan.get('lsifre') == vkn[:2] + vkn[-2:] and '__VIEWSTATE' in alan
                     and alan.get('btngiris') == 'Giriş Yap')
            girisler.append((vkn, dogru))
            if not dogru:
                return self.gonder(200, sayfa('<p>Giriş bilgileri hatalı.</p>'))
            return self.gonder(302, Location='/odeme.aspx', Set_Cookie=f'oturum={vkn}; Path=/; HttpOnly')
        if self.path == '/sonuc.aspx' and self.oturum():
            no = f'VP{9000000000000000 + next(sayac)}'
            return self.gonder(200, sayfa(f'''<h3>Onay Formu</h3>
<label>Açıklama</label><input value="Ödeme Başarıyla Gerçekleştirildi" readonly><br>
<label>Üye Sipariş Numarası</label><input value="700001" readonly><br>
<label>Pos Sipariş Numarası</label><input value="{no}" readonly><br>
<label>Tutar</label><input value="4.500,00" readonly><br><a href="/odeme.aspx">Anasayfaya Dön</a>'''))
        self.gonder(404, sayfa('<p>Bulunamadı</p>'))

    def do_GET(self):
        vkn = self.oturum()
        if self.path == '/odeme.aspx':
            return self.gonder(200, kart_sayfasi(vkn) if vkn else sayfa('<p>Oturum yok. Giriş yapın.</p>'))
        if self.path == '/baska-odeme.aspx' and vkn:
            return self.gonder(200, kart_sayfasi('0000000009'))
        if self.path == '/girisler':
            return self.gonder(200, '\n'.join(f'{v} {d}' for v, d in girisler))
        self.gonder(404, sayfa('<p>Bulunamadı</p>'))


class Banka(Pos):
    """Taklit 3D Secure: kısa süre sonra DenizPay sonuç sayfasına döner."""

    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length') or 0))
        self.gonder(200, sayfa(f'''<h3>3D Doğrulama</h3><p>Yapay banka sayfası</p>
<form id="g" method="post" action="http://{EMULATOR}:{POS}/sonuc.aspx"></form>
<script>setTimeout(function(){{document.getElementById('g').submit()}},1500)</script>'''))


def main():
    sunucular = [ThreadingHTTPServer(('127.0.0.1', POS), Pos), ThreadingHTTPServer(('127.0.0.1', BANKA), Banka)]
    for s in sunucular:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    print(f'Taklit DenizPay {POS}, banka {BANKA} hazır', flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == '__main__':
    main()
