// Canlı `ayarlar/android` belgesini yazar (tools/android_yayin.sh --yayinla).
// İstemci bu belgeyi yazamaz (firestore.rules); yönetici aracı Firebase CLI
// oturumuyla yazar. Uygulamadaki karşılığı lib/domain/surum.dart.
//   node android_surum_yaz.mjs <kod> <ad> <sha256> <indirme> [--zorunlu]
// --zorunlu: bu sürümün altı açılmaz. Verilmezse önceki en düşük sürüm korunur
// (ilk yayında bu sürüm).
import assert from 'node:assert/strict';
import { getFirestore } from 'firebase-admin/firestore';
import { adminApp } from './bulut.mjs';
const [kodMetni, sonAd, sha256, indirme, ...secenek] = process.argv.slice(2);
const son = Number(kodMetni);
assert.ok(Number.isInteger(son) && son >= 1, 'Sürüm kodu geçersiz.');
assert.match(sonAd, /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/, 'Sürüm adı geçersiz.');
assert.match(sha256, /^[0-9a-f]{64}$/, 'SHA-256 geçersiz.');
const adres = new URL(indirme);
assert.ok(adres.protocol === 'https:' && !adres.username && !adres.port, 'İndirme adresi yalnız https.');
assert.ok(secenek.every(s => s === '--zorunlu'), `Bilinmeyen seçenek: ${secenek}`);
const db = getFirestore(adminApp());
const ref = db.collection('ayarlar').doc('android');
await db.runTransaction(async tx => {
  const onceki = (await tx.get(ref)).data();
  assert.ok(!onceki || son >= onceki.son, `Yayındaki sürüm (${onceki?.son}) bundan yeni; geri alınmaz.`);
  const enDusuk = secenek.includes('--zorunlu') ? son : (onceki?.enDusuk ?? son);
  const belge = { enDusuk, son, sonAd, indirme: adres.href, sha256 };
  tx.set(ref, belge);
  console.log('ayarlar/android:', JSON.stringify(belge));
});
process.exit(0);
