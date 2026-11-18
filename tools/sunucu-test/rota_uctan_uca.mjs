// Rota uçtan uca (ROTA_MIMARI §7, Aşama 1 madde 7). YALNIZ Android emülatörü + Firebase emülatörü
// (demo-bup-pos). tools/rota_test.sh çalıştırır; uygulama emülatör yapılandırmasıyla derlenmiş olmalı.
//
// Senaryo: temiz kurulum → izin → uygulama açılır → terminal başvuru bırakır (kod Kotlin = JS) →
// merkez onaylar ve takibi açar → emülatör GPS'i bir güzergâh boyunca yürür → parçalar kurala uygun
// gelir, canlı durum güncellenir → merkez takibi kapatır (olay gelir) → uygulama zorla durdurulur,
// yeniden açılır (olay gelir) → bütün parçalarda sıra boşluksuzdur, aynı kayıt iki kez yoktur.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { parcaDogrula, bosluklar, terminalKodu } from '../../docs/rota/sozlesme/dogrula.mjs';

const cihaz = process.argv[2];
assert.match(cihaz ?? '', /^emulator-\d+$/, 'Yalnız emülatör: node rota_uctan_uca.mjs emulator-NNNN');
const ADB = `${process.env.ANDROID_HOME ?? `${process.env.HOME}/Android/Sdk`}/platform-tools/adb`;
const adb = (...a) => execFileSync(ADB, ['-s', cihaz, ...a], { encoding: 'utf8' });
assert.equal(adb('shell', 'getprop', 'ro.kernel.qemu').trim() || adb('shell', 'getprop', 'ro.boot.qemu').trim(), '1', 'Cihaz emülatör değil');

const PAKET = 'com.bup.sanalpos', proje = 'demo-bup-pos';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
await fetch(`http://127.0.0.1:9098/emulator/v1/projects/${proje}/accounts`, { method: 'DELETE' });
await fetch(`http://127.0.0.1:8088/emulator/v1/projects/${proje}/databases/(default)/documents`, { method: 'DELETE' });
const db = getFirestore(initializeApp({ projectId: proje }));

const bekle = ms => new Promise(r => setTimeout(r, ms));
async function bekleyerek(ad, sn, f) {
  const son = Date.now() + sn * 1000;
  for (;;) {
    const v = await f();
    if (v) return v;
    if (Date.now() > son) throw Error(`Zaman aşımı: ${ad}`);
    await bekle(1000);
  }
}
let konumNo = 0;
const konum = (en, boy) => { adb('emu', 'geo', 'fix', String(boy), String(en)); konumNo++; };
async function parcalar(uid) {
  const q = await db.collection('rotaParcalar').where('cihaz', '==', uid).get();
  return q.docs.map(d => {
    const v = d.data();
    // Okuyucu gibi: Timestamp → ms, sonra sözleşme doğrulaması.
    const p = { ...v, bas: v.bas.toMillis(), bit: v.bit.toMillis() };
    const r = parcaDogrula(p, d.id);
    assert.deepEqual(r.hatalar, [], `Bozuk parça ${d.id}`);
    assert.equal(r.atlanan, 0, `Atlanan kayıt ${d.id}`);
    assert.ok(v.alindi.toMillis() > 0 && v.silinme.toMillis() === v.bit.toMillis() + 90 * 864e5);
    return { id: d.id, ...p, ...r };
  }).sort((a, b) => a.ilk - b.ilk);
}
const olaylar = ps => ps.flatMap(p => p.olaylar.map(o => o.tur));

console.log('== Temiz kurulum, izin, konum açık');
adb('shell', 'pm', 'clear', PAKET);
for (const izin of ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'ACCESS_BACKGROUND_LOCATION'])
  adb('shell', 'pm', 'grant', PAKET, `android.permission.${izin}`);
adb('shell', 'cmd', 'location', 'set-location-enabled', 'true');
let en = 38.4100, boy = 27.1300;
konum(en, boy);
adb('shell', 'am', 'start', '-W', '-n', `${PAKET}/.MainActivity`);

console.log('== Başvuru');
const basvuru = await bekleyerek('başvuru', 90, async () => (await db.collection('rotaBasvurular').get()).docs[0]);
const uid = basvuru.id, b = basvuru.data();
assert.equal(b.kod, await terminalKodu(uid), 'Terminal kodu Kotlin ve JS arasında farklı');
assert.equal(b.s, 1);
console.log(`   terminal ${b.kod} (${b.uretici} ${b.model}, Android ${b.android})`);
await bekle(5000);
assert.equal((await db.collection('rotaParcalar').get()).size, 0, 'Onaysız terminal yazmamalı');

console.log('== Merkez onaylar, takip açık (sıklık 5 sn)');
const cihazAyari = takip => ({ ad: 'Terminal Test', aktif: true, takip, hareketSn: 5, durgunSn: 5, depoSn: 5, gonderimSn: 15,
  olusturma: FieldValue.serverTimestamp(), guncelleme: FieldValue.serverTimestamp(), guncelleyen: 'test', denetim: 'X'.repeat(20) });
await db.doc(`rotaCihazlar/${uid}`).set(cihazAyari(true));

console.log('== Güzergâh (kuzeye, ~55 m adımlar)');
const yuru = async (adim, ms = 2000) => { for (let i = 0; i < adim; i++) { en += 0.0005; konum(en, boy); await bekle(ms); } };
await yuru(25);
const ilk = await bekleyerek('ilk parçalar', 120, async () => {
  const ps = await parcalar(uid);
  return ps.reduce((t, p) => t + p.noktalar.length, 0) >= 10 ? ps : null;
});
const noktalar = ilk.flatMap(p => p.noktalar);
assert.ok(noktalar.every(n => n.kay === 'g' && !n.sahte), 'Emülatör GPS noktası beklenir');
assert.ok(noktalar.at(-1).en > 38.4105, 'Güzergâh ilerlemeli');
assert.ok(olaylar(ilk).includes('hizmet_basladi'));
assert.ok(olaylar(ilk).includes('takip_acildi'));
const durum = (await db.doc(`rotaSonDurum/${uid}`).get()).data();
assert.equal(durum.s, 1);
assert.ok(['hareket', 'durgun'].includes(durum.durum), `durum: ${durum.durum}`);
console.log(`   ${ilk.length} parça, ${noktalar.length} nokta; canlı durum ${durum.durum}`);

console.log('== Merkez takibi kapatır');
await db.doc(`rotaCihazlar/${uid}`).set(cihazAyari(false));
await yuru(5);
const kapali = await bekleyerek('takip_kapandi olayı', 120, async () => {
  const ps = await parcalar(uid);
  return olaylar(ps).includes('takip_kapandi') ? ps : null;
});
const kapanisSira = kapali.flatMap(p => p.olaylar).find(o => o.tur === 'takip_kapandi').q;
const sonrakiNokta = kapali.flatMap(p => p.noktalar).find(n => n.q > kapanisSira);
assert.equal(sonrakiNokta, undefined, 'Takip kapalıyken nokta alınmamalı');
assert.equal((await db.doc(`rotaSonDurum/${uid}`).get()).data().durum, 'kapali');

console.log('== Takip açık, uygulama zorla durdurulup yeniden açılır');
await db.doc(`rotaCihazlar/${uid}`).set(cihazAyari(true));
await yuru(5);
adb('shell', 'am', 'force-stop', PAKET);
await yuru(3);
adb('shell', 'am', 'start', '-W', '-n', `${PAKET}/.MainActivity`);
await yuru(15);
await bekleyerek('yeniden başlama', 150, async () => {
  const ps = await parcalar(uid);
  const baslama = ps.flatMap(p => p.olaylar).filter(o => o.tur === 'hizmet_basladi');
  const sonNokta = ps.flatMap(p => p.noktalar).at(-1);
  return baslama.length >= 2 && sonNokta && sonNokta.q > baslama.at(-1).q ? ps : null;
});

console.log('== Telefon yeniden başlar (uygulama açılmadan hizmet kendiliğinden başlamalı)');
adb('reboot');
adb('wait-for-device');
await bekleyerek('açılış', 180, async () => adb('shell', 'getprop', 'sys.boot_completed').trim() === '1');
await yuru(20);
const acilis = await bekleyerek('açılış olayı ve sonrası nokta', 180, async () => {
  const ps = await parcalar(uid);
  const o = ps.flatMap(p => p.olaylar).filter(x => x.tur === 'acilis').at(-1);
  const sonNokta = ps.flatMap(p => p.noktalar).at(-1);
  return o && sonNokta.q > o.q ? ps : null;
});
console.log(`   açılıştan sonra ${acilis.flatMap(p => p.noktalar).length} nokta (toplam)`);
const sonAyrinti = acilis.flatMap(p => p.olaylar).filter(o => o.tur === 'hizmet_basladi').at(-1).a;
assert.equal(sonAyrinti, 'acilis', 'Hizmeti açılış alıcısı başlatmalı');

console.log('== Bekçi: hizmet ölür (17 Kasım gecesi gibi), bekçi yeniden başlatır');
// Bekçi işi yeniden başlatmadan sonra da kayıtlı olmalı (kalıcı iş).
assert.match(adb('shell', 'dumpsys', 'jobscheduler', PAKET), /RotaBekci/, 'Bekçi işi kayıtlı değil');
// Kurulumdaki pil muafiyetinin karşılığı (Android 12+'da arka plandan başlatma buna bağlı).
adb('shell', 'dumpsys', 'deviceidle', 'whitelist', `+${PAKET}`);
// Kök yetkisiyle durdurulur: sistem (START_STICKY) yeniden başlatmaz; geri getiren yalnız bekçi olabilir.
// "am stop-service" durdurduğunda da 255 döner; sonucu çıktısından ve hizmet listesinden okunur.
try {
  adb('shell', 'su', '0', 'am', 'stop-service', '-n', `${PAKET}/.rota.RotaHizmeti`);
} catch (e) {
  assert.match(String(e.stdout) + String(e.stderr), /Service stopped/, 'Hizmet durdurulamadı');
}
await yuru(3);
assert.doesNotMatch(adb('shell', 'dumpsys', 'activity', 'services', PAKET), /RotaHizmeti/, 'Hizmet durmalıydı');
adb('shell', 'cmd', 'jobscheduler', 'run', '-f', PAKET, '4702');
await yuru(15);
await bekleyerek('bekçinin başlattığı hizmet ve sonrası nokta', 150, async () => {
  const ps = await parcalar(uid);
  const o = ps.flatMap(p => p.olaylar).filter(x => x.tur === 'hizmet_basladi' && x.a === 'bekci').at(-1);
  const sonNokta = ps.flatMap(p => p.noktalar).at(-1);
  return o && sonNokta.q > o.q ? ps : null;
});

console.log('== Bütünlük');
const son = await parcalar(uid);
assert.deepEqual(bosluklar(son), [], 'Parçalar arası kayıp kayıt');
const siralar = son.flatMap(p => [...p.noktalar, ...p.olaylar].map(x => x.q));
assert.equal(new Set(siralar).size, siralar.length, 'Aynı kayıt iki kez');
assert.equal(son[0].ilk, 1, 'İlk kayıt sıra 1');
const zamanlar = son.flatMap(p => p.noktalar.map(n => n.z));
assert.ok(zamanlar.every((z, i) => i === 0 || z >= zamanlar[i - 1]), 'Nokta zamanları sıralı');
console.log(`   ${son.length} parça, ${siralar.length} kayıt (sıra 1–${son.at(-1).son}), boşluk yok, çift yok`);
console.log(`ROTA UÇTAN UCA: GEÇTİ (${konumNo} emülatör konumu)`);
process.exit(0);
