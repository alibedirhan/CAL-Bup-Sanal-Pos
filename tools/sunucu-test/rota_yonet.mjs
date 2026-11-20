// Rota yönetici aracı (docs/ROTA_MIMARI.md §8 madde 8): CAL_bup Rota sekmesi gelene kadar terminal
// başvurusunu onaylamak ve takibi açıp kapatmak için. Canlıda Firebase CLI oturumuyla (REST,
// rota_rest.mjs); her değişiklik aynı toplu yazmada rotaDenetim'e yazılır. ROTA_EMULATOR=1 ile
// yalnız yerel emülatörde (demo-bup-pos).
//
//   node rota_yonet.mjs basvurular
//   node rota_yonet.mjs onayla KOD "Ali telefon"      (takip kapalı başlar)
//   node rota_yonet.mjs takip KOD ac|kapat
//   node rota_yonet.mjs kaldir KOD                     (onayı kaldırır; kayıtlar kalır)
//   node rota_yonet.mjs durum
//   node rota_yonet.mjs parcalar KOD               (gelen veriyi sözleşmeyle doğrular)
//   node rota_yonet.mjs gonderim KOD SANIYE    (gönderim aralığı, 15–3600; terminal 0.13.1+)
//   node rota_yonet.mjs aralik KOD 15 120 300      (konum alma: hareket, durgun, depoda sn)
//   node rota_yonet.mjs depo "Ad" ENLEM BOYLAM M    (depo bölgesi; aynı adlı güncellenir)
//   node rota_yonet.mjs ilk-yonetici EPOSTA "Ad Soyad" (rota yöneticisi; yalnız hiç yokken)
import { randomBytes } from 'node:crypto';
import { rotaRest } from './rota_rest.mjs';

const db = await rotaRest({ emulator: process.env.ROTA_EMULATOR === '1' });
const YAZAN = 'yonetici-araci';
const [komut, ...arg] = process.argv.slice(2);

const denetimId = () => {
  const A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return [...randomBytes(20)].map(b => A[b % A.length]).join('');
};
/** Değişiklik ve denetim kaydı aynı toplu yazmada (kural da bunu ister). */
async function yaz(yol, veri, eylem, { birlestir = false, yeni = false, zamanlar = [] } = {}) {
  const id = denetimId();
  await db.toplu([
    { yol: `rotaDenetim/${id}`, veri: { yazan: YAZAN, eylem, hedef: yol }, zamanlar: ['zaman'], yeni: true },
    { yol, veri: { ...veri, guncelleyen: YAZAN, denetim: id }, zamanlar: ['guncelleme', ...zamanlar], birlestir, yeni },
  ]);
}
/** Terminal kodu (6 karakter) ya da kodlar çakışırsa uzun kimlik (uid). */
async function koddan(kod) {
  if (/^[A-Za-z0-9]{20,128}$/.test(kod ?? '')) {
    const d = await db.al(`rotaBasvurular/${kod}`);
    if (!d) throw Error('Bu kimlikle başvuru yok.');
    return d;
  }
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(kod ?? '')) throw Error('Kod 6 karakter olmalı (ör. K9WMEY).');
  const q = await db.esit('rotaBasvurular', 'kod', kod);
  if (q.length !== 1) {
    throw Error(q.length ? `Bu kodla ${q.length} başvuru var; kod yerine uzun kimliği yazın: ${q.map(d => d.id).join(', ')}`
      : 'Bu kodla başvuru yok.');
  }
  return q[0];
}
const tarih = t => t instanceof Date ? t.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }) : '—';

switch (komut) {
  case 'basvurular': {
    const [b, c] = await Promise.all([db.liste('rotaBasvurular'), db.liste('rotaCihazlar')]);
    const cihaz = new Map(c.map(d => [d.id, d.veri]));
    if (!b.length) console.log('Başvuru yok.');
    for (const { id, veri: v } of b) {
      const k = cihaz.get(id);
      const durum = !k ? 'ONAY BEKLİYOR' : !k.aktif ? 'onay kaldırıldı' : k.takip ? `onaylı, takip AÇIK (${k.ad})` : `onaylı, takip kapalı (${k.ad})`;
      console.log(`${v.kod}  ${v.uretici} ${v.model} (Android ${v.android}, sürüm ${v.surum})  ${tarih(v.olusturma)}  ${durum}`);
    }
    break;
  }
  case 'onayla': {
    const [kod, ad] = arg;
    if (!ad || ad.length > 40) throw Error('Ad gerekli (en çok 40 karakter).');
    const b = await koddan(kod);
    if (await db.al(`rotaCihazlar/${b.id}`)) throw Error('Zaten onaylı. Takip için: takip KOD ac');
    await yaz(`rotaCihazlar/${b.id}`, { ad, aktif: true, takip: false, hareketSn: 15, durgunSn: 120, depoSn: 300 }, 'onay',
      { yeni: true, zamanlar: ['olusturma'] });
    console.log(`${kod} onaylandı (${ad}). Takip kapalı; açmak için: takip ${kod} ac`);
    break;
  }
  case 'takip': {
    const [kod, ne] = arg;
    if (!['ac', 'kapat'].includes(ne)) throw Error('takip KOD ac|kapat');
    const b = await koddan(kod), c = await db.al(`rotaCihazlar/${b.id}`);
    if (!c?.veri.aktif) throw Error('Terminal onaylı değil.');
    await yaz(`rotaCihazlar/${b.id}`, { takip: ne === 'ac' }, ne === 'ac' ? 'takip_ac' : 'takip_kapat', { birlestir: true });
    console.log(`${kod}: takip ${ne === 'ac' ? 'AÇIK' : 'kapalı'}.`);
    break;
  }
  case 'kaldir': {
    const b = await koddan(arg[0]);
    if (!(await db.al(`rotaCihazlar/${b.id}`))) throw Error('Terminal onaylı değil.');
    await yaz(`rotaCihazlar/${b.id}`, { aktif: false, takip: false }, 'onay_kaldir', { birlestir: true });
    console.log(`${arg[0]}: onay kaldırıldı. Terminal artık yazamaz; eski kayıtlar durur.`);
    break;
  }
  case 'durum': {
    const [s, b] = await Promise.all([db.liste('rotaSonDurum'), db.liste('rotaBasvurular')]);
    const kod = new Map(b.map(d => [d.id, d.veri.kod]));
    if (!s.length) console.log('Henüz durum yok.');
    for (const { id, veri: v } of s) {
      const parca = await db.say('rotaParcalar', 'cihaz', id);
      console.log(`${kod.get(id) ?? id}: ${v.durum}, pil %${v.pil}${v.sarj ? ' (şarjda)' : ''}, bekleyen ${v.bekleyen}, ` +
        `son nokta ${v.z ? tarih(new Date(v.z)) : '—'}, güncelleme ${tarih(v.guncelleme)}, ${parca} parça`);
    }
    break;
  }
  case 'parcalar': {
    // Gelen parçaları CAL_bup'ın kullanacağı sözleşme doğrulayıcısından geçirir; boşluk/çift arar.
    const { parcaDogrula, bosluklar } = await import('../../docs/rota/sozlesme/dogrula.mjs');
    const b = await koddan(arg[0]);
    const ps = (await db.esit('rotaParcalar', 'cihaz', b.id))
      .map(({ id, veri: v }) => ({ id, ...v, bas: v.bas.getTime(), bit: v.bit.getTime(), alindi: v.alindi }))
      .sort((x, y) => x.ilk - y.ilk);
    let nokta = 0, gecersiz = 0, atlanan = 0;
    const olaylar = {}, kaynak = {}, dog = [];
    for (const p of ps) {
      const r = parcaDogrula(p, p.id);
      if (!r.gecerli) gecersiz++;
      atlanan += r.atlanan;
      nokta += r.noktalar.length;
      for (const n of r.noktalar) { kaynak[n.kay] = (kaynak[n.kay] ?? 0) + 1; dog.push(n.dog); }
      for (const o of r.olaylar) olaylar[o.tur] = (olaylar[o.tur] ?? 0) + 1;
    }
    const siralar = ps.flatMap(p => [...p.n, ...p.olaylar].map(x => x.q));
    dog.sort((x, y) => x - y);
    console.log(`${ps.length} parça, ${nokta} nokta, sıra ${ps[0]?.ilk ?? '—'}–${ps.at(-1)?.son ?? '—'}; geçersiz parça ${gecersiz}, ` +
      `atlanan kayıt ${atlanan}, boşluk ${JSON.stringify(bosluklar(ps))}, çift ${siralar.length - new Set(siralar).size}`);
    console.log(`kaynak ${JSON.stringify(kaynak)}; doğruluk ortanca ${dog.length ? Math.round(dog[dog.length >> 1]) : '—'} m; olaylar ${JSON.stringify(olaylar)}`);
    if (ps.length) {
      const son = ps.at(-1);
      console.log(`son parça: ${tarih(new Date(son.bas))} – ${tarih(new Date(son.bit))}, alındı ${tarih(son.alindi)}, pil %${son.pil}`);
    }
    break;
  }
  case 'gonderim': {
    // Gönderim aralığı (K31; terminal 0.13.1+). Canlı kural bu alanı tanımalı (firestore.rules, 18 Kasım).
    const [kod, sn] = arg;
    const n = Number(sn);
    if (!Number.isInteger(n) || n < 15 || n > 3600) throw Error('gonderim KOD SANIYE (15–3600; varsayılan 120)');
    const b = await koddan(kod);
    if (!(await db.al(`rotaCihazlar/${b.id}`))) throw Error('Önce onaylayın: onayla KOD "Ad"');
    await yaz(`rotaCihazlar/${b.id}`, { gonderimSn: n }, 'ayar', { birlestir: true });
    console.log(`${kod}: gönderim ${n} sn'de bir.`);
    break;
  }
  case 'aralik': {
    // Konum alma aralıkları (CAL_bup Ayarlar → Terminaller ile aynı alanlar ve sınırlar).
    const [kod, ...sn] = arg;
    const [h, d, p] = sn.map(Number);
    const gecerli = (x, en) => Number.isInteger(x) && x >= en && x <= 3600;
    if (!gecerli(h, 5) || !gecerli(d, 5) || !gecerli(p, 5)) throw Error('aralik KOD HAREKET DURGUN DEPO (sn, 5–3600; varsayılan 15 120 300)');
    const b = await koddan(kod);
    if (!(await db.al(`rotaCihazlar/${b.id}`))) throw Error('Önce onaylayın: onayla KOD "Ad"');
    await yaz(`rotaCihazlar/${b.id}`, { hareketSn: h, durgunSn: d, depoSn: p }, 'cihaz_ayar', { birlestir: true });
    console.log(`${kod}: hareket ${h}, durgun ${d}, depoda ${p} sn.`);
    break;
  }
  case 'depo': {
    // Depo bölgesi (rotaAyar/genel; CAL_bup Ayarlar → Depo ile aynı biçim). Aynı adlı depo güncellenir.
    const [ad, ...sayi] = arg;
    const [en, boy, yaricap] = sayi.map(Number);
    if (!ad?.trim() || ad.trim().length > 40 || !(Math.abs(en) <= 90) || !(Math.abs(boy) <= 180)
      || !(yaricap >= 10 && yaricap <= 5000)) throw Error('depo "Ad" ENLEM BOYLAM YARICAP_M (10–5000)');
    const eski = (await db.al('rotaAyar/genel'))?.veri;
    const depolar = (Array.isArray(eski?.depolar) ? eski.depolar : []).filter(x => x.ad !== ad.trim());
    if (depolar.length >= 10) throw Error('En çok 10 depo.');
    depolar.push({ ad: ad.trim(), en, boy, yaricap });
    const bolgeler = Array.isArray(eski?.bolgeler) ? eski.bolgeler : ['İzmir', 'Aydın', 'Manisa'];
    await yaz('rotaAyar/genel', { depolar, bolgeler }, 'ayar');
    console.log(`Depolar: ${depolar.map(x => `${x.ad} (${x.en}, ${x.boy}, ${x.yaricap} m)`).join('; ')}; bölgeler: ${bolgeler.join(', ')}.`);
    break;
  }
  case 'ilk-yonetici': {
    const [eposta, ad] = arg;
    if (!/^[a-z0-9._%+-]{1,64}@[a-z0-9.-]{1,190}$/.test(eposta ?? '') || !ad) throw Error('ilk-yonetici küçük-harf-eposta "Ad Soyad"');
    if ((await db.esit('rotaYetkileri', 'rol', 'yonetici', 1)).length) throw Error('Rota yöneticisi zaten var. Bu araç yeniden yetki vermez.');
    await yaz(`rotaYetkileri/${eposta}`, { ad, rol: 'yonetici', aktif: true }, 'yetki', { yeni: true });
    console.log(`${eposta} rota yöneticisi oldu (Google girişiyle).`);
    break;
  }
  default:
    console.log('Komutlar: basvurular | onayla KOD "Ad" | takip KOD ac|kapat | kaldir KOD | durum | parcalar KOD | gonderim KOD SN | aralik KOD H D P | depo "Ad" EN BOY M | ilk-yonetici EPOSTA "Ad"');
    process.exitCode = 1;
}
