// Canlı `ayarlar/android` belgesini yazar (tools/android_yayin.sh --yayinla).
// İstemci bu belgeyi yazamaz (firestore.rules); yönetici aracı Firebase CLI
// oturumuyla yazar. Uygulamadaki karşılığı lib/domain/surum.dart.
//   node android_surum_yaz.mjs <kod> <ad> <sha256> <indirme> [--zorunlu]
// --zorunlu: bu sürümün altı açılmaz. Verilmezse önceki en düşük sürüm korunur
// (ilk yayında bu sürüm).
import assert from 'node:assert/strict';
import { cloudFetch, projectId } from './bulut.mjs';
const [kodMetni, sonAd, sha256, indirme, ...secenek] = process.argv.slice(2);
const son = Number(kodMetni);
assert.ok(Number.isInteger(son) && son >= 1, 'Sürüm kodu geçersiz.');
assert.match(sonAd, /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/, 'Sürüm adı geçersiz.');
assert.match(sha256, /^[0-9a-f]{64}$/, 'SHA-256 geçersiz.');
const adres = new URL(indirme);
assert.ok(adres.protocol === 'https:' && !adres.username && !adres.port, 'İndirme adresi yalnız https.');
assert.ok(secenek.every(s => s === '--zorunlu'), `Bilinmeyen seçenek: ${secenek}`);
const adres1 = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/ayarlar/android`;
const okunan = await cloudFetch(adres1);
assert.ok(okunan.status === 200 || okunan.status === 404, `Sürüm belgesi okunamadı (${okunan.status}).`);
const alanlar = okunan.status === 200 ? okunan.data.fields : null;
const sayi = ad => alanlar?.[ad]?.integerValue === undefined ? undefined : Number(alanlar[ad].integerValue);
const oncekiSon = sayi('son'), oncekiEnDusuk = sayi('enDusuk');
assert.ok(oncekiSon === undefined || son >= oncekiSon, `Yayındaki sürüm (${oncekiSon}) bundan yeni; geri alınmaz.`);
const enDusuk = secenek.includes('--zorunlu') ? son : (oncekiEnDusuk ?? son);
const belge = { enDusuk, son, sonAd, indirme: adres.href, sha256 };
// Önkoşul: okunduğundan beri değişmediyse (veya hâlâ yoksa) yazılır.
const onkosul = okunan.status === 200
  ? `currentDocument.updateTime=${encodeURIComponent(okunan.data.updateTime)}`
  : 'currentDocument.exists=false';
const yazilan = await cloudFetch(`${adres1}?${onkosul}`, { method: 'PATCH', body: { fields: {
  enDusuk: { integerValue: String(enDusuk) }, son: { integerValue: String(son) },
  sonAd: { stringValue: sonAd }, indirme: { stringValue: adres.href }, sha256: { stringValue: sha256 },
} } });
assert.equal(yazilan.status, 200, `Sürüm belgesi yazılamadı (${yazilan.status}).`);
console.log('ayarlar/android:', JSON.stringify(belge));
