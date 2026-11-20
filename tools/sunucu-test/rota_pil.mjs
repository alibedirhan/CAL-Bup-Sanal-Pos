// Salt okunur pil raporu: node rota_pil.mjs KOD [KOD...] — parçalardaki pil/şarj çizelgesi ve şarjsız
// dönemlerde saatlik düşüş (20 Kasım 2026, TC15 sahada ölçüm için).
import { rotaRest } from './rota_rest.mjs';
const db = await rotaRest({ emulator: false });
const t = ms => new Date(ms).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' });
for (const kod of process.argv.slice(2)) {
  const [b] = await db.esit('rotaBasvurular', 'kod', kod);
  const ps = (await db.esit('rotaParcalar', 'cihaz', b.id)).map(x => x.veri)
    .map(v => ({ z: v.alindi.getTime?.() ?? +v.alindi, pil: v.pil, sarj: v.sarj, n: v.n.length,
      olay: v.olaylar.map(o => o.tur).join(',') })).sort((a, c) => a.z - c.z);
  console.log(`\n== ${kod} (${ps.length} parça)`);
  let onceki = null, seg = null; const segs = [];
  for (const p of ps) {
    const deg = !onceki || p.sarj !== onceki.sarj || Math.abs(p.pil - onceki.pil) >= 5 || p.z - onceki.z > 3600e3 || p.olay;
    if (deg) console.log(`${t(p.z)}  pil %${p.pil} ${p.sarj ? 'şarjda' : ''} nokta ${p.n} ${p.olay}`);
    if (!p.sarj) { if (!seg) seg = { a: p, b: p }; else seg.b = p; } else if (seg) { segs.push(seg); seg = null; }
    onceki = p;
  }
  if (seg) segs.push(seg);
  for (const s of segs) { const h = (s.b.z - s.a.z) / 3600e3; if (h > 0.5)
    console.log(`  şarjsız: ${t(s.a.z)} → ${t(s.b.z)}  ${h.toFixed(1)} sa, %${s.a.pil}→%${s.b.pil}, saatte %${((s.a.pil - s.b.pil) / h).toFixed(1)}`); }
}
