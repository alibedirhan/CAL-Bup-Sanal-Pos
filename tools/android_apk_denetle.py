#!/usr/bin/env python3
"""Sürüm APK'sının yayın kapısı (tools/android_yayin.sh; docs/ANDROID_PLANI.md).

Bir koşul tutmazsa durur. Tutarsa tek satır JSON yazar: kod, ad, boyut, sha256.
Kullanım: python3 tools/android_apk_denetle.py <apk> <surum-adi> <surum-kodu>
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

# İmza sertifikası (docs/ANDROID_PLANI.md §4.10). Değişirse kurulu uygulamalar
# güncellenemez: bu değer bilerek sabittir.
IMZA = '0c7696fc91b4ac71916937a0508eb54c02b3bc7ac114c353e8d36f48d70947db'
PAKET = 'com.bup.sanalpos'
# İzin listesi: yeni bir izin (eklenti güncellemesiyle gelen dahil) bilinçli
# eklenmeden yayın durur. Mikrofon, depolama, kişiler, bildirim vb. yoktur.
# Konum ve ön plan hizmeti izinleri rota içindir (docs/ROTA_MIMARI.md; Ali'nin
# 16–17 Kasım 2026 kararları K1–K29). Bildirim izni bilerek yok (M17).
IZINLER = {
    'android.permission.ACCESS_FINE_LOCATION', 'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION', 'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_LOCATION', 'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    # Alarm bekçisi (ROTA_MIMARI M19, 18 Kasım 2026).
    'android.permission.USE_EXACT_ALARM', 'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.USE_BIOMETRIC', 'android.permission.USE_FINGERPRINT',
    'android.permission.NFC', 'android.permission.CAMERA',
    'com.google.android.providers.gsf.permission.READ_GSERVICES',
    'com.bup.sanalpos.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}
ABI = {'arm64-v8a', 'armeabi-v7a'}


def dur(neden):
    sys.exit(f'APK denetimi BAŞARISIZ: {neden}')


def arac(ad):
    kok = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Android/Sdk')) / 'build-tools'
    surumler = sorted((p for p in kok.iterdir() if (p / ad).exists()),
                      key=lambda p: [int(x) for x in re.findall(r'\d+', p.name)])
    if not surumler:
        dur(f'{ad} bulunamadı ({kok})')
    return str(surumler[-1] / ad)


def calistir(*komut):
    r = subprocess.run(komut, capture_output=True, text=True)
    if r.returncode != 0:
        dur(f'{Path(komut[0]).name} hata verdi: {r.stderr.strip()[:300]}')
    return r.stdout


def main():
    apk, beklenen_ad, beklenen_kod = sys.argv[1], sys.argv[2], sys.argv[3]
    aapt2, apksigner = arac('aapt2'), arac('apksigner')

    # İmza: tek imzacı, beklenen sertifika, v2 şeması.
    imza = calistir(apksigner, 'verify', '--verbose', '--print-certs', apk)
    ozetler = re.findall(r'certificate SHA-256 digest: ([0-9a-f]{64})', imza)
    if ozetler != [IMZA]:
        dur(f'imza sertifikası beklenen değil: {ozetler}')
    if 'Verified using v2 scheme (APK Signature Scheme v2): true' not in imza:
        dur('APK v2 imzası yok')

    rozet = calistir(aapt2, 'dump', 'badging', apk)
    paket = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", rozet, re.M)
    if not paket or paket.groups() != (PAKET, beklenen_kod, beklenen_ad):
        dur(f'paket/sürüm uyuşmuyor: {paket and paket.groups()}')
    if "minSdkVersion:'28'" not in rozet:
        dur('en düşük Android sürümü 28 değil')
    if 'application-debuggable' in rozet:
        dur('hata ayıklanabilir derleme')
    izinler = set(re.findall(r"^uses-permission: name='([^']+)'", rozet, re.M))
    if izinler - IZINLER:
        dur(f'izin listesinde olmayan izin: {sorted(izinler - IZINLER)}')
    abi = re.search(r"^native-code: (.*)$", rozet, re.M)
    if not abi or set(re.findall(r"'([^']+)'", abi.group(1))) != ABI:
        dur(f'işlemci türleri beklenen değil: {abi and abi.group(1)}')
    for ozellik in ('android.hardware.nfc', 'android.hardware.camera', 'android.hardware.camera.any'):
        if f"uses-feature: name='{ozellik}'" in rozet:
            dur(f'{ozellik} zorunlu olmamalı (NFC/kamerasız cihaza da kurulur)')

    manifest = calistir(aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk)
    for oznitelik in ('allowBackup', 'usesCleartextTraffic'):
        satir = re.search(rf'A: http://schemas.android.com/apk/res/android:{oznitelik}\(0x[0-9a-f]+\)=(\S+)', manifest)
        if not satir or satir.group(1) not in ('false', '(type 0x12)0x0'):
            dur(f'{oznitelik} kapalı değil: {satir and satir.group(1)}')
    if 'android:debuggable' in manifest or 'android:testOnly' in manifest:
        dur('manifestte debuggable/testOnly var')

    with zipfile.ZipFile(apk) as z:
        adlar = z.namelist()
        # Ağ güvenliği: yapılandırma düz HTTP'yi kapatır, hiçbir kaynak izin vermez
        # (hata ayıklama eki sürüme girmez).
        kapali = 0
        for ad in adlar:
            if not (ad.startswith('res/') and ad.endswith('.xml')):
                continue
            ham = z.read(ad)
            if not ham.startswith(b'\x03\x00\x08\x00'):
                # Derlenmemiş (ham) XML kaynağı: metin olarak bakılır.
                if re.search(rb'cleartextTrafficPermitted\s*=\s*"true"', ham):
                    dur(f'{ad}: düz HTTP izni')
                continue
            agac = calistir(aapt2, 'dump', 'xmltree', '--file', ad, apk)
            if re.search(r'cleartextTrafficPermitted\(?[^=]*=(true|\(type 0x12\)0xffffffff)', agac):
                dur(f'{ad}: düz HTTP izni')
            kapali += len(re.findall(r'cleartextTrafficPermitted=false', agac))
        if kapali == 0:
            dur('ağ güvenliği yapılandırması (düz HTTP kapalı) bulunamadı')
        for ad in (a for a in adlar if re.fullmatch(r'classes\d*\.dex', a)):
            dex = z.read(ad)
            for yasak in (b'Landroidx/test/', b'integration_test', b'IntegrationTestPlugin'):
                if yasak in dex:
                    dur(f'{ad}: test kodu ({yasak.decode()})')
        kutuphaneler = [a for a in adlar if a.endswith('/libapp.so')]
        if not kutuphaneler:
            dur('libapp.so yok')
        for ad in kutuphaneler:
            kod = z.read(ad)
            for yasak in (b'10.0.2.2', b'demo-bup-pos', b'demo-public-key'):
                if yasak in kod:
                    dur(f'{ad}: test adresi/projesi ({yasak.decode()})')
            for gerekli in (b'bup-sanal-pos-izmir', b'https://denizpay.bupilic.com.tr'):
                if gerekli not in kod:
                    dur(f'{ad}: canlı yapılandırma yok ({gerekli.decode()})')

    veri = Path(apk).read_bytes()
    print(json.dumps({
        'kod': int(beklenen_kod), 'ad': beklenen_ad, 'boyut': len(veri),
        'sha256': hashlib.sha256(veri).hexdigest(),
    }))


main()
