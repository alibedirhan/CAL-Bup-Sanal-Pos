// Rota uyku (Doze) deneyi. YALNIZ Android emülatörü + Firebase emülatörü (demo-bup-pos).
// 20 Kasım 2026: TC15'ler şarjda değilken ve kullanılmazken saatte 3–4 nokta gönderdi (beklenen ~30).
// Bu deney, ekran kapalı + şarjsız + derin uykuda (deviceidle force-idle) terminalin konum alıp
// almadığını pil muafiyetli ve muafiyetsiz iki aşamada ölçer. Uygulama emülatör yapılandırmasıyla
// derlenmiş olmalı (tools/rota_test.sh'deki debug APK).
//
//   firebase emulators:exec --only auth,firestore --project demo-bup-pos \
//     "node tools/sunucu-test/rota_uyku_deneyi.mjs emulator-5584 [dakika]"
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const cihaz = process.argv[2];
const DK = Number(process.argv[3] ?? 10);
assert.match(cihaz ?? '', /^emulator-\d+$/, 'Yalnız emülatör: node rota_uyku_deneyi.mjs emulator-NNNN [dakika]');
const ADB = `${process.env.ANDROID_HOME ?? `${process.env.HOME}/Android/Sdk`}/platform-tools/adb`;
const adb = (...a) => execFileSync(ADB, ['-s', cihaz, ...a], { encoding: 'utf8' });
assert.equal(adb('shell', 'getprop', 'ro.kernel.qemu').trim() || adb('shell', 'getprop', 'ro.boot.qemu').trim(), '1', 'Cihaz emülatör değil');

const PAKET = 'com.bup.sanalpos', proje = 'demo-bup-pos';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
await fetch(`http://127.0.0.1:9098/emulator/v1/projects/${proje}/accounts`, { method: 'DELETE' });
await fetch(`http://127.0.0.1:8088/emulator/v1/projects/${proje}/databases/(default)/documents`, { method: 'DELETE' });
const db = getFirestore(initializeApp({ projectId: proje }));
const bekle = ms => new Promise(r => setTimeout(r, ms));
const saat = ms => new Date(ms).toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul' });
async function bekleyerek(ad, sn, f) {
  const son = Date.now() + sn * 1000;
  for (;;) {
    const v = await f();
    if (v) return v;
    if (Date.now() > son) throw Error(`Zaman aşımı: ${ad}`);
    await bekle(2000);
  }
}

// Sabit konum (durgun terminal); emülatör GPS'i her 5 sn beslenir (gerçek uydu gibi sürekli fix).
const EN = 38.4121, BOY = 27.2454;
const besle = setInterval(() => { try { adb('emu', 'geo', 'fix', String(BOY), String(EN)); } catch { /* uyku */ } }, 5000);

console.log('== Kurulum (gerçek ayarlar: hareket 15, durgun 120, depoda 120, gönderim 60)');
adb('shell', 'pm', 'clear', PAKET);
for (const izin of ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'ACCESS_BACKGROUND_LOCATION'])
  adb('shell', 'pm', 'grant', PAKET, `android.permission.${izin}`);
adb('shell', 'cmd', 'location', 'set-location-enabled', 'true');
adb('shell', 'am', 'start', '-W', '-n', `${PAKET}/.MainActivity`);
const basvuru = await bekleyerek('başvuru', 120, async () => (await db.collection('rotaBasvurular').get()).docs[0]);
const uid = basvuru.id;
await db.doc(`rotaCihazlar/${uid}`).set({ ad: 'Uyku Deneyi', aktif: true, takip: true, hareketSn: 15, durgunSn: 120, depoSn: 120,
  gonderimSn: 60, olusturma: FieldValue.serverTimestamp(), guncelleme: FieldValue.serverTimestamp(), guncelleyen: 'test', denetim: 'X'.repeat(20) });

async function noktalar() {
  const q = await db.collection('rotaParcalar').where('cihaz', '==', uid).get();
  return q.docs.flatMap(d => { const v = d.data(); return v.n.map(n => ({ ...n, al: v.alindi.toMillis() })); });
}
console.log('== Durgun kipe geçiş bekleniyor (3 dk hareketsiz)');
await bekleyerek('durgun', 420, async () => (await db.doc(`rotaSonDurum/${uid}`).get()).data()?.durum === 'durgun');
await bekle(150_000);

async function asama(ad, muaf) {
  adb('shell', 'dumpsys', 'deviceidle', 'whitelist', `${muaf ? '+' : '-'}${PAKET}`);
  adb('shell', 'dumpsys', 'battery', 'unplug');
  adb('shell', 'input', 'keyevent', 'KEYCODE_SLEEP');
  await bekle(3000);
  adb('shell', 'dumpsys', 'deviceidle', 'force-idle', 'deep');
  const bas = Date.now();
  const durumlar = [];
  for (let i = 0; i < DK; i++) {
    await bekle(60_000);
    durumlar.push(adb('shell', 'dumpsys', 'deviceidle', 'get', 'deep').trim());
  }
  const bit = Date.now();
  // Uyku sırasında sunucuya ulaşan noktalar (gönderim de uykudan etkilenir).
  const uykudaUlasan = (await noktalar()).filter(n => n.z >= bas && n.z <= bit && n.al <= bit).length;
  adb('shell', 'dumpsys', 'deviceidle', 'unforce');
  adb('shell', 'dumpsys', 'battery', 'reset');
  adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP');
  await bekle(150_000); // kuyruğun boşalması
  const ns = (await noktalar()).filter(n => n.z >= bas && n.z <= bit).sort((a, b) => a.z - b.z);
  const beklenen = Math.floor((bit - bas) / 120_000);
  const sonuc = { ad, muaf, sure: `${saat(bas)}–${saat(bit)}`, beklenen, alinan: ns.length, uykudaUlasan,
    zamanlar: ns.map(n => saat(n.z)).join(' '), uykuDurumu: [...new Set(durumlar)].join(',') };
  console.log(JSON.stringify(sonuc));
  return sonuc;
}

console.log(`== Aşama A: pil muafiyeti VAR, ekran kapalı, şarjsız, derin uyku ${DK} dk`);
const a = await asama('muafiyetli', true);
await bekle(60_000);
console.log(`== Aşama B: pil muafiyeti YOK, ekran kapalı, şarjsız, derin uyku ${DK} dk`);
const b = await asama('muafiyetsiz', false);
clearInterval(besle);
console.log(`SONUÇ: muafiyetli ${a.alinan}/${a.beklenen} nokta (uykuda ulaşan ${a.uykudaUlasan}), ` +
  `muafiyetsiz ${b.alinan}/${b.beklenen} nokta (uykuda ulaşan ${b.uykudaUlasan})`);
process.exit(0);
