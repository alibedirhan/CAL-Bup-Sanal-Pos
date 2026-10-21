"""Basit geometrik uygulama işaretini üretir. Yalnız geliştirme: Pillow gerekir."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

kok = Path(__file__).resolve().parents[1]


def ikon(yol, boyut):
    katsayi = 4
    n = boyut * katsayi
    resim = Image.new('RGB', (n, n), '#16343e')
    ciz = ImageDraw.Draw(resim)
    def kutu(x1, y1, x2, y2):
        return tuple(round(v * n) for v in (x1, y1, x2, y2))
    ciz.rounded_rectangle(kutu(.20, .29, .80, .71), radius=round(n*.055), fill='#ffffff')
    ciz.rectangle(kutu(.20, .39, .80, .47), fill='#08786e')
    ciz.rounded_rectangle(kutu(.28, .56, .43, .60), radius=round(n*.015), fill='#16343e')
    ciz.rounded_rectangle(kutu(.49, .56, .58, .60), radius=round(n*.015), fill='#a9c5c7')
    yol.parent.mkdir(parents=True, exist_ok=True)
    resim.resize((boyut, boyut), Image.Resampling.LANCZOS).save(yol)


for boyut in (192, 512):
    for ad in (f'Icon-{boyut}.png', f'Icon-maskable-{boyut}.png'):
        ikon(kok / 'web/icons' / ad, boyut)
ikon(kok / 'web/icons/apple-touch-icon.png', 180)
ikon(kok / 'web/favicon.png', 32)
for ad, boyut in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    ikon(kok / f'android/app/src/main/res/mipmap-{ad}/ic_launcher.png', boyut)
ios = kok / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for giris in json.loads((ios / 'Contents.json').read_text())['images']:
    if 'filename' in giris:
        boyut = round(float(giris['size'].split('x')[0]) * float(giris['scale'].removesuffix('x')))
        ikon(ios / giris['filename'], boyut)
print('Web ve platform simgeleri üretildi.')
