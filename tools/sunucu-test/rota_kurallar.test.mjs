// Rota kuralları (docs/ROTA_MIMARI.md §4, §6). Firestore emülatöründe (demo-bup-pos) yapay verilerle.
import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp,
} from 'firebase/firestore';

let env;
const T1 = 'terminalBir0000000000000001', T2 = 'terminalIki0000000000000002', T3 = 'terminalUc00000000000000003';
const YONETICI = 'ali@example.test', IZLEYICI = 'izle@example.test', PASIF = 'pasif@example.test';
const SIMDI = Date.now();

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-bup-pos', firestore: {
    host: '127.0.0.1', port: 8088, rules: await readFile('../../firestore.rules', 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });

const terminal = uid => env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const google = (eposta, dogrulandi = true) => env.authenticatedContext(`g-${eposta.split('@')[0]}`, {
  email: eposta, email_verified: dogrulandi, firebase: { sign_in_provider: 'google.com' },
}).firestore();
// Sanal POS'un parolalı yöneticisi (terminallerde açık olan oturum türü, K19).
const parolali = () => env.authenticatedContext('admin', {
  email: YONETICI, email_verified: true, firebase: { sign_in_provider: 'password' },
}).firestore();
const yonetici = () => google(YONETICI);
const gYazan = `g-${YONETICI.split('@')[0]}`;

const basvuru = (patch = {}) => ({ s: 1, kod: 'K7P3XZ', model: 'TC15', uretici: 'Zebra', android: 33, surum: 23,
  olusturma: serverTimestamp(), ...patch });
const cihaz = (patch = {}) => ({ ad: 'Terminal 1', aktif: true, takip: true, hareketSn: 15, durgunSn: 120, depoSn: 300,
  olusturma: serverTimestamp(), guncelleme: serverTimestamp(), guncelleyen: gYazan, denetim: 'D'.repeat(20), ...patch });
const durum = (patch = {}) => ({ s: 1, z: SIMDI - 5000, en: 38.43, boy: 27.21, dog: 6.5, hiz: 11.2, yon: 90, pil: 80,
  sarj: false, durum: 'hareket', bekleyen: 0, surum: 23, guncelleme: serverTimestamp(), ...patch });
const nokta = (q, z) => ({ q, z, en: 38.43 + q / 1e4, boy: 27.21, dog: 5, hiz: 10, yon: 45, yuk: null, kay: 'g', sahte: false, zayif: false });
function parca(uid, ilk, adet, patch = {}) {
  const n = Array.from({ length: adet }, (_, i) => nokta(ilk + i, SIMDI - (adet - i) * 15000));
  const bas = Timestamp.fromMillis(n[0]?.z ?? SIMDI - 60000), bit = Timestamp.fromMillis(n.at(-1)?.z ?? SIMDI - 60000);
  return { s: 1, cihaz: uid, ilk, son: ilk + adet - 1, bas, bit, alindi: serverTimestamp(),
    silinme: Timestamp.fromMillis(bit.toMillis() + 90 * 864e5), cihazSaati: SIMDI, pil: 80, sarj: false, surum: 23,
    n, olaylar: [], ...patch };
}
function gonder(db, uid, veri, kimlik = `${uid}_${veri.ilk}`) {
  const b = writeBatch(db);
  b.set(doc(db, 'rotaParcalar', kimlik), veri);
  b.set(doc(db, 'rotaSonDurum', uid), durum());
  return b.commit();
}
let sayac = 0;
const denetimId = () => `D${String(++sayac).padStart(19, '0')}`;
function yonet(db, yol, veri, eylem = 'ayar', { guncelle = false } = {}) {
  const b = writeBatch(db), id = denetimId();
  b.set(doc(db, 'rotaDenetim', id), { yazan: gYazan, eylem, hedef: yol, zaman: serverTimestamp() });
  const hedef = doc(db, ...yol.split('/'));
  if (guncelle) b.update(hedef, { ...veri, denetim: id }); else b.set(hedef, { ...veri, denetim: id });
  return b.commit();
}

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore(), b = writeBatch(db), eski = Timestamp.fromMillis(SIMDI - 3600e3);
    b.set(doc(db, 'kullanicilar', 'admin'), { ad: 'Yönetici', eposta: YONETICI, yonetici: true, aktif: true,
      olusturma: eski, guncelleme: eski });
    for (const [e, rol, aktif] of [[YONETICI, 'yonetici', true], [IZLEYICI, 'izleyici', true], [PASIF, 'izleyici', false]])
      b.set(doc(db, 'rotaYetkileri', e), { ad: 'Örnek Kişi', rol, aktif, guncelleme: eski, guncelleyen: 'kurulum', denetim: 'X'.repeat(20) });
    for (const t of [T1, T2, T3]) b.set(doc(db, 'rotaBasvurular', t), { ...basvuru(), olusturma: eski });
    b.set(doc(db, 'rotaCihazlar', T1), { ...cihaz(), olusturma: eski, guncelleme: eski });
    b.set(doc(db, 'rotaCihazlar', T3), { ...cihaz({ aktif: false }), olusturma: eski, guncelleme: eski });
    b.set(doc(db, 'rotaSonDurum', T1), { ...durum(), guncelleme: eski });
    b.set(doc(db, 'rotaAraclar', 'arac01'), { no: '01', plasiyer: 'Örnek Plasiyer', renk: '#1f77b4', yakit: 'dizel',
      tuketim: 9.5, aktif: true, guncelleme: eski, guncelleyen: 'kurulum', denetim: 'X'.repeat(20) });
    b.set(doc(db, 'rotaAyar', 'genel'), { depolar: [{ ad: 'Depo', en: 38.46, boy: 27.22, yaricap: 150 }], bolgeler: ['İzmir'],
      guncelleme: eski, guncelleyen: 'kurulum', denetim: 'X'.repeat(20) });
    b.set(doc(db, 'rotaParcalar', `${T1}_1`), { ...parca(T1, 1, 2), alindi: Timestamp.fromMillis(SIMDI - 91 * 864e5) });
    b.set(doc(db, 'rotaParcalar', `${T1}_3`), { ...parca(T1, 3, 2), alindi: eski });
    b.set(doc(db, 'rotaDenetim', 'E'.repeat(20)), { yazan: gYazan, eylem: 'ayar', hedef: `rotaCihazlar/${T1}`, zaman: eski });
    await b.commit();
  });
});

// --- Terminal ---
test('Terminal yalnız kendi başvurusunu bir kez bırakır', async () => {
  const yeni = 'terminalYeni00000000000009';
  await assertSucceeds(getDoc(doc(terminal(yeni), 'rotaBasvurular', yeni)));
  await assertFails(setDoc(doc(terminal(yeni), 'rotaBasvurular', T2), basvuru()));
  await assertFails(setDoc(doc(terminal(yeni), 'rotaBasvurular', yeni), basvuru({ kod: 'K7P3X0' })));
  await assertFails(setDoc(doc(terminal(yeni), 'rotaBasvurular', yeni), basvuru({ fazla: 1 })));
  await assertFails(setDoc(doc(terminal(yeni), 'rotaBasvurular', yeni), basvuru({ olusturma: Timestamp.now() })));
  await assertSucceeds(setDoc(doc(terminal(yeni), 'rotaBasvurular', yeni), basvuru()));
  await assertFails(setDoc(doc(terminal(yeni), 'rotaBasvurular', yeni), basvuru()));
  await assertFails(deleteDoc(doc(terminal(yeni), 'rotaBasvurular', yeni)));
  await assertFails(getDocs(collection(terminal(yeni), 'rotaBasvurular')));
});

test('Parolalı Sanal POS oturumu başvuru bırakamaz, rota verisine erişemez', async () => {
  const db = parolali();
  await assertFails(setDoc(doc(db, 'rotaBasvurular', 'admin'), basvuru()));
  for (const yol of [['rotaCihazlar', T1], ['rotaSonDurum', T1], ['rotaParcalar', `${T1}_3`], ['rotaAyar', 'genel'],
    ['rotaAraclar', 'arac01'], ['rotaYetkileri', YONETICI], ['rotaBasvurular', T2]]) await assertFails(getDoc(doc(db, ...yol)));
  await assertFails(getDocs(collection(db, 'rotaParcalar')));
  await assertFails(updateDoc(doc(db, 'rotaCihazlar', T1), { takip: false }));
  await assertFails(gonder(db, 'admin', parca('admin', 1, 1)));
});

test('Onaylı terminal parçayı durum güncellemesiyle birlikte yazar', async () => {
  await assertSucceeds(gonder(terminal(T1), T1, parca(T1, 5, 3)));
  const olayli = parca(T1, 8, 1, { olaylar: [{ q: 9, z: SIMDI - 1000, tur: 'konum_kapandi' }] });
  olayli.son = 9;
  // Durum güncellemesi 15 sn'den sık olamaz: aynı anda ikinci gönderim reddedilir.
  await assertFails(gonder(terminal(T1), T1, olayli));
});

test('Parça durum güncellemesi olmadan yazılamaz', async () => {
  await assertFails(setDoc(doc(terminal(T1), 'rotaParcalar', `${T1}_5`), parca(T1, 5, 1)));
});

test('Onaysız veya onayı kaldırılmış terminal yazamaz', async () => {
  await assertFails(gonder(terminal(T2), T2, parca(T2, 1, 1)));
  await assertFails(setDoc(doc(terminal(T2), 'rotaSonDurum', T2), durum()));
  await assertFails(gonder(terminal(T3), T3, parca(T3, 1, 1)));
  await assertFails(getDoc(doc(terminal(T2), 'rotaAyar', 'genel')));
  await assertSucceeds(getDoc(doc(terminal(T1), 'rotaAyar', 'genel')));
});

test('Parça biçimi ve kimliği sıkı denetlenir', async () => {
  const bozuk = [
    [parca(T1, 5, 1), `${T1}_6`],
    [parca(T1, 5, 1), `${T1}_05`],
    [parca(T1, 5, 1, { cihaz: T2 })],
    [parca(T1, 5, 2, { son: 7 })],
    [parca(T1, 5, 0)],
    [parca(T1, 5, 1, { s: 2 })],
    [parca(T1, 5, 1, { fazla: true })],
    [parca(T1, 5, 1, { pil: 101 })],
    [parca(T1, 5, 1, { alindi: Timestamp.now() })],
    [parca(T1, 5, 1, { silinme: Timestamp.fromMillis(SIMDI + 365 * 864e5) })],
    [parca(T1, 5, 1, { bit: Timestamp.fromMillis(SIMDI + 3600e3) })],
    [parca(T1, 5, 1, { bas: Timestamp.fromMillis(SIMDI - 41 * 864e5) })],
  ];
  const cok = parca(T1, 5, 241);
  bozuk.push([cok]);
  for (const [veri, kimlik] of bozuk) await assertFails(gonder(terminal(T1), T1, veri, kimlik));
  // Başka terminalin kimliğiyle yazılamaz.
  await assertFails(gonder(terminal(T1), T1, parca(T1, 5, 1), `${T2}_5`));
  // Denetim: bozuklar başka bir nedenle düşmüyor; aynı koşulda doğru parça kabul edilir (240 nokta sınırda).
  await assertSucceeds(gonder(terminal(T1), T1, parca(T1, 5, 240)));
});

test('Parça değiştirilemez, silinemez; aynı parça ikinci kez yazılamaz', async () => {
  const db = terminal(T1);
  await assertFails(updateDoc(doc(db, 'rotaParcalar', `${T1}_3`), { pil: 5 }));
  await assertFails(deleteDoc(doc(db, 'rotaParcalar', `${T1}_3`)));
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'rotaSonDurum', T1), { ...durum(), guncelleme: Timestamp.fromMillis(SIMDI - 3600e3) });
  });
  await assertFails(gonder(db, T1, parca(T1, 3, 2)));
});

test('Terminal yalnız kendi parçasının varlığına bakabilir (yeniden gönderim)', async () => {
  await assertSucceeds(getDoc(doc(terminal(T1), 'rotaParcalar', `${T1}_3`)));
  await assertSucceeds(getDoc(doc(terminal(T1), 'rotaParcalar', `${T1}_999`)));
  await assertFails(getDoc(doc(terminal(T2), 'rotaParcalar', `${T1}_3`)));
  await assertFails(getDocs(collection(terminal(T1), 'rotaParcalar')));
  await assertFails(getDoc(doc(terminal(T1), 'rotaSonDurum', T1)));
});

test('Terminal yalnız kendi cihaz ayarını okur, değiştiremez', async () => {
  await assertSucceeds(getDoc(doc(terminal(T1), 'rotaCihazlar', T1)));
  await assertSucceeds(getDoc(doc(terminal(T2), 'rotaCihazlar', T2)));
  await assertFails(getDoc(doc(terminal(T2), 'rotaCihazlar', T1)));
  await assertFails(updateDoc(doc(terminal(T1), 'rotaCihazlar', T1), { takip: false }));
});

test('Durum belgesi biçimi denetlenir', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'rotaSonDurum', T1), { ...durum(), guncelleme: Timestamp.fromMillis(SIMDI - 3600e3) });
  });
  for (const patch of [{ durum: 'uyuyor' }, { en: 91 }, { pil: -1 }, { fazla: 1 }, { guncelleme: Timestamp.now() }])
    await assertFails(setDoc(doc(terminal(T1), 'rotaSonDurum', T1), durum(patch)));
  await assertSucceeds(setDoc(doc(terminal(T1), 'rotaSonDurum', T1), durum({ z: null, en: null, boy: null, dog: null,
    hiz: null, yon: null, durum: 'izin_yok' })));
});

// --- Merkez ---
test('Rota izleyicisi okur, yazamaz; yetkisiz ve pasif hesaplar okuyamaz', async () => {
  const db = google(IZLEYICI);
  await assertSucceeds(getDocs(collection(db, 'rotaParcalar')));
  await assertSucceeds(getDocs(collection(db, 'rotaSonDurum')));
  await assertSucceeds(getDocs(collection(db, 'rotaCihazlar')));
  await assertSucceeds(getDoc(doc(db, 'rotaYetkileri', IZLEYICI)));
  await assertFails(getDocs(collection(db, 'rotaYetkileri')));
  await assertFails(getDocs(collection(db, 'rotaBasvurular')));
  await assertFails(yonet(db, `rotaCihazlar/${T1}`, { takip: false, guncelleme: serverTimestamp(), guncelleyen: 'g-izle' }, 'takip_kapat', { guncelle: true }));
  for (const db2 of [google(PASIF), google('yabanci@example.test'), google(IZLEYICI, false), env.unauthenticatedContext().firestore()])
    await assertFails(getDocs(collection(db2, 'rotaParcalar')));
});

test('Yönetici başvuruyu denetim kaydıyla onaylar', async () => {
  const db = yonetici();
  await assertSucceeds(getDocs(collection(db, 'rotaBasvurular')));
  await assertFails(setDoc(doc(db, 'rotaCihazlar', T2), cihaz()));
  await assertFails(yonet(db, 'rotaCihazlar/baskaUid', cihaz(), 'onay'));
  await assertFails(yonet(db, `rotaCihazlar/${T2}`, cihaz({ hareketSn: 2 }), 'onay'));
  await assertSucceeds(yonet(db, `rotaCihazlar/${T2}`, cihaz(), 'onay'));
});

test('Takip aç/kapa taze denetim kaydı ister; eski kayıt yeniden kullanılamaz', async () => {
  const db = yonetici(), ref = doc(db, 'rotaCihazlar', T1);
  await assertFails(updateDoc(ref, { takip: false, guncelleme: serverTimestamp(), guncelleyen: gYazan, denetim: 'E'.repeat(20) }));
  await assertFails(yonet(db, `rotaCihazlar/${T2}`, { takip: false, guncelleme: serverTimestamp(), guncelleyen: gYazan }, 'takip_kapat', { guncelle: true }));
  await assertFails(yonet(db, `rotaCihazlar/${T1}`, { takip: false, guncelleme: serverTimestamp(), guncelleyen: 'baskasi' }, 'takip_kapat', { guncelle: true }));
  await assertFails(yonet(db, `rotaCihazlar/${T1}`, { takip: false, olusturma: serverTimestamp(), guncelleme: serverTimestamp(), guncelleyen: gYazan }, 'takip_kapat', { guncelle: true }));
  await assertSucceeds(yonet(db, `rotaCihazlar/${T1}`, { takip: false, guncelleme: serverTimestamp(), guncelleyen: gYazan }, 'takip_kapat', { guncelle: true }));
  await assertFails(deleteDoc(ref));
});

test('Denetim kayıtları değiştirilemez; yalnız yönetici yazar', async () => {
  await assertFails(updateDoc(doc(yonetici(), 'rotaDenetim', 'E'.repeat(20)), { eylem: 'baska' }));
  await assertFails(deleteDoc(doc(yonetici(), 'rotaDenetim', 'E'.repeat(20))));
  await assertFails(setDoc(doc(google(IZLEYICI), 'rotaDenetim', 'F'.repeat(20)), { yazan: 'g-izle', eylem: 'ayar', hedef: 'x/yy', zaman: serverTimestamp() }));
  await assertFails(setDoc(doc(yonetici(), 'rotaDenetim', 'F'.repeat(20)), { yazan: 'baskasi', eylem: 'ayar', hedef: 'x/yy', zaman: serverTimestamp() }));
});

test('Yetki: yönetici yalnız izleyici ekler; kendini ve yöneticiyi değiştiremez', async () => {
  const db = yonetici(), kayit = (patch = {}) => ({ ad: 'Yönetim Üyesi', rol: 'izleyici', aktif: true,
    guncelleme: serverTimestamp(), guncelleyen: gYazan, ...patch });
  await assertSucceeds(yonet(db, 'rotaYetkileri/mudur@example.test', kayit(), 'yetki'));
  await assertFails(yonet(db, 'rotaYetkileri/mudur2@example.test', kayit({ rol: 'yonetici' }), 'yetki'));
  await assertFails(yonet(db, `rotaYetkileri/${YONETICI}`, kayit(), 'yetki'));
  await assertFails(yonet(db, 'rotaYetkileri/Buyuk@Example.test', kayit(), 'yetki'));
  await assertSucceeds(yonet(db, `rotaYetkileri/${IZLEYICI}`, kayit({ aktif: false }), 'yetki'));
  const ikinci = 'yonetici2@example.test';
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'rotaYetkileri', ikinci), { ad: 'İkinci', rol: 'yonetici', aktif: true,
      guncelleme: Timestamp.now(), guncelleyen: 'kurulum', denetim: 'X'.repeat(20) });
  });
  await assertFails(yonet(db, `rotaYetkileri/${ikinci}`, kayit(), 'yetki'));
  await assertFails(yonet(google(IZLEYICI), 'rotaYetkileri/mudur3@example.test', kayit({ guncelleyen: 'g-izle' }), 'yetki'));
});

test('Araç, atama ve genel ayar yalnız yöneticide; atamalar yalnız eklenir', async () => {
  const db = yonetici();
  const arac = { no: '02', plasiyer: 'İkinci Plasiyer', renk: '#d62728', yakit: 'dizel', tuketim: 10,
    aktif: true, guncelleme: serverTimestamp(), guncelleyen: gYazan };
  await assertFails(yonet(db, 'rotaAraclar/arac02', { ...arac, renk: 'red' }, 'arac'));
  await assertSucceeds(yonet(db, 'rotaAraclar/arac02', arac, 'arac'));
  const atama = { cihaz: T1, arac: 'arac02', bas: Timestamp.now(), yazan: gYazan, zaman: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'rotaAtamalar', 'A'.repeat(20)), atama));
  await assertFails(setDoc(doc(db, 'rotaAtamalar', 'B'.repeat(20)), { ...atama, arac: 'yokArac' }));
  await assertFails(setDoc(doc(db, 'rotaAtamalar', 'C'.repeat(20)), { ...atama, cihaz: 'yokCihaz' }));
  await assertFails(updateDoc(doc(db, 'rotaAtamalar', 'A'.repeat(20)), { arac: 'arac01' }));
  await assertFails(deleteDoc(doc(db, 'rotaAtamalar', 'A'.repeat(20))));
  await assertFails(setDoc(doc(google(IZLEYICI), 'rotaAtamalar', 'D'.repeat(20)), { ...atama, yazan: 'g-izle' }));
  await assertSucceeds(yonet(db, 'rotaAyar/genel', { depolar: [], bolgeler: ['İzmir', 'Aydın', 'Manisa'],
    guncelleme: serverTimestamp(), guncelleyen: gYazan }, 'genel_ayar'));
  await assertFails(yonet(db, 'rotaAyar/baska', { depolar: [], bolgeler: [], guncelleme: serverTimestamp(), guncelleyen: gYazan }, 'genel_ayar'));
});

test('Yalnız 90 günden eski parça ve yalnız onaysız başvuru silinir', async () => {
  const db = yonetici();
  await assertFails(deleteDoc(doc(db, 'rotaParcalar', `${T1}_3`)));
  await assertSucceeds(deleteDoc(doc(db, 'rotaParcalar', `${T1}_1`)));
  await assertFails(deleteDoc(doc(google(IZLEYICI), 'rotaParcalar', `${T1}_3`)));
  await assertFails(deleteDoc(doc(db, 'rotaBasvurular', T1)));
  await assertSucceeds(deleteDoc(doc(db, 'rotaBasvurular', T2)));
});
