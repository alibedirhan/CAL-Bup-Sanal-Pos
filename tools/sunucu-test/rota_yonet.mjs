// Rota yönetici aracı (docs/ROTA_MIMARI.md §8 madde 8): CAL_bup Rota sekmesi gelene kadar terminal
// başvurusunu onaylamak ve takibi açıp kapatmak için. Firebase CLI oturumuyla (admin) çalışır; her
// değişiklik rotaDenetim'e yazılır. ROTA_EMULATOR=1 ile yalnız yerel emülatörde (demo-bup-pos).
//
//   node rota_yonet.mjs basvurular
//   node rota_yonet.mjs onayla KOD "Ali telefon"      (takip kapalı başlar)
//   node rota_yonet.mjs takip KOD ac|kapat
//   node rota_yonet.mjs kaldir KOD                     (onayı kaldırır; kayıtlar kalır)
//   node rota_yonet.mjs durum
//   node rota_yonet.mjs ilk-yonetici EPOSTA "Ad Soyad" (rota yöneticisi; yalnız hiç yokken)
import { randomBytes } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const emulator = process.env.ROTA_EMULATOR === '1';
let app;
if (emulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8088';
  app = initializeApp({ projectId: 'demo-bup-pos' });
} else {
  app = (await import('./bulut.mjs')).adminApp();
}
const db = getFirestore(app);
const YAZAN = 'yonetici-araci';
const [komut, ...arg] = process.argv.slice(2);

const denetimId = () => {
  const A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return [...randomBytes(20)].map(b => A[b % A.length]).join('');
};
/** Değişiklik ve denetim kaydı aynı toplu yazmada (kural da bunu ister). */
async function yaz(yol, veri, eylem, birlestir = false) {
  const id = denetimId(), b = db.batch();
  b.set(db.doc(`rotaDenetim/${id}`), { yazan: YAZAN, eylem, hedef: yol, zaman: FieldValue.serverTimestamp() });
  b.set(db.doc(yol), { ...veri, guncelleme: FieldValue.serverTimestamp(), guncelleyen: YAZAN, denetim: id }, { merge: birlestir });
  await b.commit();
}
/** Terminal kodu (6 karakter) ya da kodlar çakışırsa uzun kimlik (uid). */
async function koddan(kod) {
  if (/^[A-Za-z0-9]{20,128}$/.test(kod ?? '')) {
    const d = await db.doc(`rotaBasvurular/${kod}`).get();
    if (!d.exists) throw Error('Bu kimlikle başvuru yok.');
    return d;
  }
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(kod ?? '')) throw Error('Kod 6 karakter olmalı (ör. K9WMEY).');
  const q = await db.collection('rotaBasvurular').where('kod', '==', kod).get();
  if (q.size !== 1) {
    throw Error(q.size ? `Bu kodla ${q.size} başvuru var; kod yerine uzun kimliği yazın: ${q.docs.map(d => d.id).join(', ')}`
      : 'Bu kodla başvuru yok.');
  }
  return q.docs[0];
}
const tarih = t => t?.toDate?.().toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }) ?? '—';

switch (komut) {
  case 'basvurular': {
    const [b, c] = await Promise.all([db.collection('rotaBasvurular').get(), db.collection('rotaCihazlar').get()]);
    const cihaz = new Map(c.docs.map(d => [d.id, d.data()]));
    if (!b.size) console.log('Başvuru yok.');
    for (const d of b.docs) {
      const v = d.data(), k = cihaz.get(d.id);
      const durum = !k ? 'ONAY BEKLİYOR' : !k.aktif ? 'onay kaldırıldı' : k.takip ? `onaylı, takip AÇIK (${k.ad})` : `onaylı, takip kapalı (${k.ad})`;
      console.log(`${v.kod}  ${v.uretici} ${v.model} (Android ${v.android}, sürüm ${v.surum})  ${tarih(v.olusturma)}  ${durum}`);
    }
    break;
  }
  case 'onayla': {
    const [kod, ad] = arg;
    if (!ad || ad.length > 40) throw Error('Ad gerekli (en çok 40 karakter).');
    const b = await koddan(kod);
    if ((await db.doc(`rotaCihazlar/${b.id}`).get()).exists) throw Error('Zaten onaylı. Takip için: takip KOD ac');
    await yaz(`rotaCihazlar/${b.id}`, { ad, aktif: true, takip: false, hareketSn: 15, durgunSn: 120, depoSn: 300,
      olusturma: FieldValue.serverTimestamp() }, 'onay');
    console.log(`${kod} onaylandı (${ad}). Takip kapalı; açmak için: takip ${kod} ac`);
    break;
  }
  case 'takip': {
    const [kod, ne] = arg;
    if (!['ac', 'kapat'].includes(ne)) throw Error('takip KOD ac|kapat');
    const b = await koddan(kod), ref = db.doc(`rotaCihazlar/${b.id}`);
    const c = await ref.get();
    if (!c.exists || !c.data().aktif) throw Error('Terminal onaylı değil.');
    await yaz(ref.path, { takip: ne === 'ac' }, ne === 'ac' ? 'takip_ac' : 'takip_kapat', true);
    console.log(`${kod}: takip ${ne === 'ac' ? 'AÇIK' : 'kapalı'}.`);
    break;
  }
  case 'kaldir': {
    const b = await koddan(arg[0]);
    await yaz(`rotaCihazlar/${b.id}`, { aktif: false, takip: false }, 'onay_kaldir', true);
    console.log(`${arg[0]}: onay kaldırıldı. Terminal artık yazamaz; eski kayıtlar durur.`);
    break;
  }
  case 'durum': {
    const [s, b] = await Promise.all([db.collection('rotaSonDurum').get(), db.collection('rotaBasvurular').get()]);
    const kod = new Map(b.docs.map(d => [d.id, d.data().kod]));
    if (!s.size) console.log('Henüz durum yok.');
    for (const d of s.docs) {
      const v = d.data();
      const parca = await db.collection('rotaParcalar').where('cihaz', '==', d.id).count().get();
      console.log(`${kod.get(d.id) ?? d.id}: ${v.durum}, pil %${v.pil}${v.sarj ? ' (şarjda)' : ''}, bekleyen ${v.bekleyen}, ` +
        `son nokta ${v.z ? new Date(v.z).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }) : '—'}, ` +
        `güncelleme ${tarih(v.guncelleme)}, ${parca.data().count} parça`);
    }
    break;
  }
  case 'ilk-yonetici': {
    const [eposta, ad] = arg;
    if (!/^[a-z0-9._%+-]{1,64}@[a-z0-9.-]{1,190}$/.test(eposta ?? '') || !ad) throw Error('ilk-yonetici küçük-harf-eposta "Ad Soyad"');
    const var_ = await db.collection('rotaYetkileri').where('rol', '==', 'yonetici').limit(1).get();
    if (!var_.empty) throw Error('Rota yöneticisi zaten var. Bu araç yeniden yetki vermez.');
    await yaz(`rotaYetkileri/${eposta}`, { ad, rol: 'yonetici', aktif: true }, 'yetki');
    console.log(`${eposta} rota yöneticisi oldu (Google girişiyle).`);
    break;
  }
  default:
    console.log('Komutlar: basvurular | onayla KOD "Ad" | takip KOD ac|kapat | kaldir KOD | durum | ilk-yonetici EPOSTA "Ad"');
    process.exitCode = 1;
}
process.exit();
