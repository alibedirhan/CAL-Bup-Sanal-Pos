"""Yer imi kaynağını köken sabitleriyle `javascript:` adresine çevirir.

Kaynakta satır sonu yorumu, yüzde işareti, ters tırnak bulunmamalıdır; tam
satır yorumlar silinir, satırlar boşlukla birleştirilir. Yalnız yerel derleme.
"""
import json
import re
from pathlib import Path
from urllib.parse import quote, urlparse

KOK = Path(__file__).resolve().parent
CANLI_UYGULAMA = 'https://bup-sanal-pos-izmir.web.app'
CANLI_POS = 'https://denizpay.bupilic.com.tr'
# Ödeme sitesinin taklidi; testler yalnız bu yerel kökenle çalışır.
TAKLIT_POS = 'http://127.0.0.1:4199'


def _koken(deger: str) -> str:
    u = urlparse(deger)
    if u.scheme not in {'https', 'http'} or not u.netloc or u.path or u.query or u.fragment:
        raise SystemExit(f'Geçersiz köken: {deger}')
    if u.scheme == 'http' and u.hostname != '127.0.0.1':
        raise SystemExit('Yalnız yerel test kökeni HTTP olabilir.')
    return deger


def yer_imi(ad: str, uygulama: str, pos: str) -> str:
    kaynak = (KOK / f'{ad}.js').read_text()
    if any(k in kaynak for k in ('%', '`', '\r', '__bupGizli')):
        raise SystemExit('Yer imi kaynağında izin verilmeyen karakter var.')
    kod = kaynak.replace('__UYGULAMA_KOKENI__', _koken(uygulama)).replace('__POS_KOKENI__', _koken(pos))
    if re.search(r'__[A-Z_]+__', kod):
        raise SystemExit('Doldurulmamış yer tutucu kaldı.')
    satirlar = [s.strip() for s in kod.splitlines()]
    kod = ' '.join(s for s in satirlar if s and not s.startswith('//'))
    if '//' in kod.replace('://', ''):
        raise SystemExit('Satır sonu yorumu birleştirmede kodu bozar.')
    # '#' adresin parça bölümünü, '%' kodlamayı başlatır; boşluklar da kodlanır.
    return 'javascript:' + quote(kod, safe="!$&'()*+,;=:@/?~-._[]{}<>|^\\\"")


def _sablon(ad: str, gerekli: tuple[str, ...]) -> str:
    sablon = (KOK.parents[1] / 'web' / ad).read_text()
    if any(y not in sablon for y in gerekli):
        raise SystemExit(f'{ad} şablonu beklenen yer tutucuları içermiyor.')
    return sablon


def sayfa_betigi(uygulama: str, pos: str) -> str:
    """`web/deneme.js` şablonunu kökenler ve deneme yer imiyle doldurur."""
    return (_sablon('deneme.js', ('__POS_KOKENI__', '__YER_IMI__'))
            .replace('__POS_KOKENI__', _koken(pos))
            .replace('__YER_IMI__', json.dumps(yer_imi('deneme', uygulama, pos))))


def kurulum_betigi(uygulama: str, pos: str) -> str:
    """`web/kurulum.js` şablonuna "BUP Doldur" yer imini yazar."""
    return _sablon('kurulum.js', ('__YER_IMI__',)).replace(
        '__YER_IMI__', json.dumps(yer_imi('doldur', uygulama, pos)))


def doldur_betigi(pos: str) -> str:
    """`web/doldur_sayfasi.js` kartı yalnız bu DenizPay kökenine gönderir."""
    return _sablon('doldur_sayfasi.js', ('__POS_KOKENI__',)).replace('__POS_KOKENI__', _koken(pos))


def sayfalar(uygulama: str, pos: str) -> dict[str, str]:
    """Derleme paketine yazılacak, kökenleri doldurulmuş sayfa betikleri."""
    return {'deneme.js': sayfa_betigi(uygulama, pos), 'kurulum.js': kurulum_betigi(uygulama, pos),
            'doldur_sayfasi.js': doldur_betigi(pos)}


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--uygulama', required=True)
    p.add_argument('--pos', required=True)
    p.add_argument('--cikti', required=True, help='sayfa betiklerinin yazılacağı klasör')
    a = p.parse_args()
    hedef = Path(a.cikti)
    hedef.mkdir(parents=True, exist_ok=True)
    for ad, icerik in sayfalar(a.uygulama, a.pos).items():
        (hedef / ad).write_text(icerik)
    for ad in ('deneme', 'doldur'):
        (hedef / f'yer_imi_{ad}.txt').write_text(yer_imi(ad, a.uygulama, a.pos))
    print(f'Yer imi hazır: {hedef}')
