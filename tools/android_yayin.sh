#!/usr/bin/env bash
# Android sürüm APK'sı (docs/ANDROID_PLANI.md Aşama 3, docs/ANDROID_KURULUM.md).
#
#   bash tools/android_yayin.sh                # DENEME: derler, denetler, sayfayı
#                                              # hazırlar; hiçbir şey yayınlanmaz
#   bash tools/android_yayin.sh --yayinla      # kullanıcı onayıyla: kurallar →
#                                              # APK (GitHub) → sayfa → ayarlar/android
#   bash tools/android_yayin.sh --yayinla --zorunlu   # bu sürümün altı açılmaz
#
# APK, Firebase Spark Hosting'de yasak olduğu için (çalıştırılabilir dosya) ayrı,
# açık, yalnız APK tutan GitHub deposunun sürüm ekidir; kurulum sayfası Hosting'de.
# Web uygulaması bu betikle yayınlanmaz (tools/yayin.sh). İmza anahtarı depo
# dışındadır (~/.bup-sanal-pos/imza/); kaybı güncellemeyi imkânsız kılar.
set -euo pipefail
cd "$(dirname "$0")/.."
yayinla=false zorunlu=false
for a in "$@"; do
  case "$a" in
    --yayinla) yayinla=true ;;
    --zorunlu) zorunlu=true ;;
    *) echo "Bilinmeyen seçenek: $a" >&2; exit 2 ;;
  esac
done
$zorunlu && ! $yayinla && { echo '--zorunlu yalnız --yayinla ile' >&2; exit 2; }
PROJE=bup-sanal-pos-izmir
INDIRME=https://bup-sanal-pos-indir.web.app/
APK_DEPO=alibedirhan/bup-sanal-pos-android

# 1. Kaynak ve yapılandırma kapısı.
python3 - <<'KAPI'
import json, re
from pathlib import Path
c = json.loads(Path('config/android.json').read_text())
assert c.get('FIREBASE_PROJECT_ID') == 'bup-sanal-pos-izmir', 'Yanlış Firebase projesi'
assert c.get('BUP_DENEME') == 'false', 'Deneme kipi açık'
for yasak in ('BUP_EMULATOR', 'BUP_EMULATOR_HOST', 'BUP_DENIZPAY_KOKENI'):
    assert yasak not in c, f'Canlı yapılandırmada {yasak} var'
assert re.fullmatch(r'1:\d+:android:[0-9a-f]+', c.get('FIREBASE_APP_ID', '')), 'Android uygulama kimliği yok'
KAPI
surum=$(sed -n 's/^version: //p' pubspec.yaml)
ad=${surum%+*} kod=${surum#*+}
[[ "$ad" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$kod" =~ ^[0-9]+$ ]] || { echo "pubspec sürümü okunamadı: $surum" >&2; exit 1; }
grep -q "const surumAdi = '$ad';" lib/ui/ortak.dart || { echo "Ekrandaki sürüm $ad değil (lib/ui/ortak.dart)" >&2; exit 1; }
imza="${BUP_IMZA:-$HOME/.bup-sanal-pos/imza/key.properties}"
[ -f "$imza" ] || { echo "İmza anahtarı yok: $imza" >&2; exit 1; }
if $yayinla; then
  [ -z "$(git status --porcelain)" ] || { echo 'Yayından önce bütün değişiklikler commit edilmeli.' >&2; exit 1; }
  [ "$(git branch --show-current)" = main ] || { echo 'Yalnız main dalından yayınlanır.' >&2; exit 1; }
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo 'main GitHub ile aynı değil (push?).' >&2; exit 1; }
fi

# 2. Derleme. --no-pub kullanılmaz: eklenti kayıt dosyası sürüm için yenilenmeli,
# yoksa yalnız geliştirmedeki test eklentisi sürüme sızmaya çalışır.
flutter pub get
flutter build apk --release --dart-define-from-file=config/android.json
apk=build/app/outputs/flutter-apk/app-release.apk

# 3. APK kapısı: imza sertifikası, paket/sürüm, minSdk, hata ayıklama, yedek,
# düz HTTP, test kodu, test adresi.
ozet=$(python3 tools/android_apk_denetle.py "$apk" "$ad" "$kod")
sha=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["sha256"])' "$ozet")
boyut=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["boyut"])' "$ozet")

# 4. Kurulum sayfası (yalnız HTML; Hosting'e APK konmaz) ve yüklenecek APK.
dosya="bup-sanal-pos-$ad.apk" etiket="v$ad"
apk_adresi="https://github.com/$APK_DEPO/releases/download/$etiket/$dosya"
rm -rf build/indir build/android_surum && mkdir -p build/indir build/android_surum
cp "$apk" "build/android_surum/$dosya"
python3 - "$ad" "$boyut" "$sha" "$dosya" "$apk_adresi" <<'SAYFA'
import sys, datetime, re
from pathlib import Path
ad, boyut, sha, dosya, adres = sys.argv[1:]
aylar = 'Ocak Şubat Mart Nisan Mayıs Haziran Temmuz Ağustos Eylül Ekim Kasım Aralık'.split()
bugun = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).date()
s = Path('tools/indir/index.html').read_text()
for k, v in {'__SURUM__': ad, '__BOYUT__': f'{int(boyut) / 1e6:.0f} MB'.replace('.', ','),
             '__TARIH__': f'{bugun.day} {aylar[bugun.month - 1]} {bugun.year}',
             '__SHA256__': sha, '__DOSYA__': dosya, '__APK__': adres}.items():
    assert k in s, k
    s = s.replace(k, v)
assert not re.search(r'__[A-Z0-9]+__', s), 'Doldurulmamış alan kaldı'
Path('build/indir/index.html').write_text(s)
SAYFA
echo "Hazır: $ad ($kod), $(( boyut / 1000000 )) MB, SHA-256 $sha"
echo "Kurulum sayfası: build/indir/ · APK: build/android_surum/$dosya → $apk_adresi"

if ! $yayinla; then
  echo 'DENEME bitti: hiçbir şey yayınlanmadı (yayın için --yayinla, kullanıcı onayıyla).'
  exit 0
fi

# 5. Yayın — sıra önemli: önce kurallar (Android "uygulama" kaydı), sonra APK,
# sonra sayfa, en son sürüm belgesi (uygulamalar ancak dosya yayındayken
# haberdar edilir). Yayınlanmış sürüm eki değiştirilmez: yeni sürüm = yeni etiket.
node tools/sunucu-test/yayin_oncesi.mjs
if gh release view "$etiket" --repo "$APK_DEPO" >/dev/null 2>&1; then
  echo "$APK_DEPO içinde $etiket zaten var; sürüm eki değiştirilmez (pubspec sürümünü artırın)." >&2
  exit 1
fi
firebase deploy --only firestore:rules,firestore:indexes --project "$PROJE"
gh release create "$etiket" "build/android_surum/$dosya" --repo "$APK_DEPO" \
  --title "BUP Sanal POS $ad" --notes "Kurulum: $INDIRME
SHA-256: $sha"
gelen=$(curl -fsSL "$apk_adresi" | sha256sum | cut -d' ' -f1)
[ "$gelen" = "$sha" ] || { echo "Yayındaki APK özeti farklı: $gelen" >&2; exit 1; }
firebase deploy --only hosting:indir --project "$PROJE"
# Yeni sürümün bütün sunuculara ulaşması birkaç saniye sürebilir (ilk yayında
# sayfa ~1 dk 404 verdi): en çok 2 dakika beklenir.
sayfa_tamam=false
for _ in $(seq 1 24); do
  sayfa=$(curl -fsSL -H 'Cache-Control: no-cache' "$INDIRME" || true)
  if grep -q "$sha" <<<"$sayfa" && grep -qF "$apk_adresi" <<<"$sayfa"; then sayfa_tamam=true; break; fi
  sleep 5
done
$sayfa_tamam || { echo 'Yayındaki kurulum sayfası bu sürümü göstermiyor' >&2; exit 1; }
secenek=()
$zorunlu && secenek=(--zorunlu)
node tools/sunucu-test/android_surum_yaz.mjs "$kod" "$ad" "$sha" "$INDIRME" "${secenek[@]}"
echo "YAYINDA: $INDIRME ($ad)"
