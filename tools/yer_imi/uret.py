"""Yer imi kaynağını köken sabitleriyle `javascript:` adresine çevirir.

Kaynakta satır sonu yorumu, yüzde işareti, ters tırnak bulunmamalıdır; tam
satır yorumlar silinir, satırlar boşlukla birleştirilir. Yalnız yerel derleme.
"""
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
    if '__' in kod.replace('__bupDeneme', ''):
        raise SystemExit('Doldurulmamış yer tutucu kaldı.')
    satirlar = [s.strip() for s in kod.splitlines()]
    kod = ' '.join(s for s in satirlar if s and not s.startswith('//'))
    if '//' in kod.replace('://', ''):
        raise SystemExit('Satır sonu yorumu birleştirmede kodu bozar.')
    # '#' adresin parça bölümünü, '%' kodlamayı başlatır; boşluklar da kodlanır.
    return 'javascript:' + quote(kod, safe="!$&'()*+,;=:@/?~-._[]{}<>|^\\\"")


def sayfa_betigi(uygulama: str, pos: str) -> str:
    """`web/deneme.js` şablonunu kökenler ve yer imiyle doldurur."""
    import json
    sablon = (KOK.parents[1] / 'web' / 'deneme.js').read_text()
    if '__POS_KOKENI__' not in sablon or '__YER_IMI__' not in sablon:
        raise SystemExit('deneme.js şablonu beklenen yer tutucuları içermiyor.')
    return (sablon.replace('__POS_KOKENI__', _koken(pos))
            .replace('__YER_IMI__', json.dumps(yer_imi('deneme', uygulama, pos))))


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--uygulama', required=True)
    p.add_argument('--pos', required=True)
    p.add_argument('--cikti', required=True, help='deneme.js yazılacak klasör')
    a = p.parse_args()
    hedef = Path(a.cikti)
    hedef.mkdir(parents=True, exist_ok=True)
    (hedef / 'deneme.js').write_text(sayfa_betigi(a.uygulama, a.pos))
    (hedef / 'yer_imi_deneme.txt').write_text(yer_imi('deneme', a.uygulama, a.pos))
    print(f'Yer imi hazır: {hedef}')
