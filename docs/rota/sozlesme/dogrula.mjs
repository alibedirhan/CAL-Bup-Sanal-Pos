// Rota parça sözleşmesi doğrulayıcısı (ROTA_MIMARI §4.1, M14). Okuyan taraf terminal verisine
// güvenmez: Firestore kuralları liste içini denetleyemez, burada her nokta/olay tek tek denetlenir.
// CAL_bup okuyucusu bu dosyanın kurallarını birebir izler; ikisi aynı örneklerle sınanır
// (parca-ornek.json). Zaman alanları burada epoch ms sayısıdır (okuyucu Timestamp'i çevirir).

export const OLAY_TURLERI = new Set(['hizmet_basladi', 'acilis', 'kapanis', 'konum_kapandi', 'konum_acildi',
  'izin_yok', 'pil_dusuk', 'saat_degisti', 'sahte_konum', 'takip_acildi', 'takip_kapandi', 'kuyruk_tasti']);

const sayi = (x, en, ust) => typeof x === 'number' && Number.isFinite(x) && x >= en && x <= ust;
const tam = (x, en, ust) => Number.isInteger(x) && x >= en && x <= ust;
const bosOlur = (x, f) => x === null || f(x);

/** Bir noktayı doğrular; geçersizse neden döner, geçerliyse null. */
export function noktaHatasi(n) {
  if (!n || typeof n !== 'object') return 'nokta değil';
  if (!tam(n.q, 1, 1e15)) return 'q';
  if (!tam(n.z, 1.5e12, 1e13)) return 'z';
  if (!sayi(n.en, -90, 90) || !sayi(n.boy, -180, 180)) return 'koordinat';
  if (!sayi(n.dog, 0, 1e5)) return 'dog';
  if (!bosOlur(n.hiz, x => sayi(x, 0, 200))) return 'hiz';
  if (!bosOlur(n.yon, x => sayi(x, 0, 360))) return 'yon';
  if (!bosOlur(n.yuk, x => sayi(x, -1000, 10000))) return 'yuk';
  if (n.kay !== 'g' && n.kay !== 'a') return 'kay';
  if (typeof n.sahte !== 'boolean' || typeof n.zayif !== 'boolean') return 'işaret';
  return null;
}

export function olayHatasi(o) {
  if (!o || typeof o !== 'object') return 'olay değil';
  if (!tam(o.q, 1, 1e15)) return 'q';
  if (!tam(o.z, 1.5e12, 1e13)) return 'z';
  if (!OLAY_TURLERI.has(o.tur)) return 'tur';
  if ('a' in o && (typeof o.a !== 'string' || o.a.length > 80)) return 'a';
  return null;
}

/**
 * Parçayı doğrular. Döner: { gecerli, noktalar, olaylar, atlanan, hatalar }. Bozuk tek bir nokta
 * bütün parçayı düşürmez (atlanır ve sayılır); parçanın kendisi bozuksa gecerli=false.
 */
export function parcaDogrula(p, kimlik) {
  const hatalar = [];
  if (!p || p.s !== 1) return { gecerli: false, noktalar: [], olaylar: [], atlanan: 0, hatalar: ['şema'] };
  if (typeof p.cihaz !== 'string' || kimlik !== `${p.cihaz}_${p.ilk}`) hatalar.push('kimlik');
  if (!tam(p.ilk, 1, 1e15) || !tam(p.son, p.ilk, 1e15)) hatalar.push('sıra');
  if (!Array.isArray(p.n) || !Array.isArray(p.olaylar)) hatalar.push('liste');
  if (hatalar.length) return { gecerli: false, noktalar: [], olaylar: [], atlanan: 0, hatalar };
  const noktalar = p.n.filter(n => !noktaHatasi(n));
  const olaylar = p.olaylar.filter(o => !olayHatasi(o));
  const siralar = [...noktalar, ...olaylar].map(x => x.q).sort((a, b) => a - b);
  // Sıralar parça aralığında ve tekil olmalı (kural sayıyı tutturur, içeriği değil).
  const tekil = new Set(siralar);
  if (tekil.size !== siralar.length || siralar.some(q => q < p.ilk || q > p.son)) hatalar.push('sıra içeriği');
  return {
    gecerli: hatalar.length === 0,
    noktalar: noktalar.sort((a, b) => a.q - b.q),
    olaylar: olaylar.sort((a, b) => a.q - b.q),
    atlanan: p.n.length + p.olaylar.length - noktalar.length - olaylar.length,
    hatalar,
  };
}

/** Bir terminalin parçaları arasındaki boşluklar (kayıp kayıtlar): [{ ilk, son }] */
export function bosluklar(parcalar) {
  const s = [...parcalar].sort((a, b) => a.ilk - b.ilk), sonuc = [];
  for (let i = 1; i < s.length; i++) if (s[i].ilk > s[i - 1].son + 1) sonuc.push({ ilk: s[i - 1].son + 1, son: s[i].ilk - 1 });
  return sonuc;
}

/** Terminal kodu (Kotlin TerminalKodu ile aynı): SHA-256(uid) ilk 30 bit, 32 harfli alfabe. */
export async function terminalKodu(uid) {
  const A = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const ozet = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(uid)));
  const b = ((ozet[0] << 24) >>> 0) + (ozet[1] << 16) + (ozet[2] << 8) + ozet[3];
  let k = '';
  for (let i = 0; i < 6; i++) k += A[Math.floor(b / 2 ** (27 - 5 * i)) & 31];
  return k;
}
