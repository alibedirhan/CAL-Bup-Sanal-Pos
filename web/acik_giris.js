// Bu cihazda açılan DenizPay girişleri (son 10, her biri 2 saat) bu kökenin yerel
// deposunda (lib/domain/acik_giris.dart). DenizPay sonuç ekranındaki "BUP Doldur"
// yer iminin açtığı sonuc.html sonucu bunlardan birine bağlar (cari_eslestir.js).
// Liste tutulur: önceki cari için açık kalmış DenizPay sekmesindeki ödeme son
// girişe yanlışlıkla bağlanmasın. Sır yoktur: kart numarası, şifre, CVV, tutar
// bulunmaz; yalnız cari adı/VKN, kartın son dört hanesi.
const ANAHTAR = 'bup-acik-giris';
const SURE = 2 * 60 * 60 * 1000, EN_FAZLA = 10;
const metin = (v, en) => typeof v === 'string' && v.length > 0 && v.length <= en && !/[\x00-\x1f\x7f]/.test(v);
export function gecerli(g, simdi = Date.now()) {
  return !!g && typeof g === 'object' && Object.keys(g).sort().join(',') === 'an,cariAd,cariId,girisId,kartSonDort,kimlikNo,son,uid,v' &&
    g.v === 2 && metin(g.uid, 128) && /^[A-Za-z0-9]{20}$/.test(g.girisId) && metin(g.cariId, 128) && metin(g.cariAd, 80) &&
    /^[0-9]{10,11}$/.test(g.kimlikNo) && /^([0-9]{4})?$/.test(g.kartSonDort) &&
    Number.isInteger(g.an) && Number.isInteger(g.son) && g.son === g.an + SURE && g.an <= simdi + 60000 && g.son > simdi;
}
// Geçerli ve süresi dolmamış girişler, eskiden yeniye.
function liste() {
  let l = [];
  try { l = JSON.parse(localStorage.getItem(ANAHTAR) ?? '[]'); } catch { l = []; }
  return (Array.isArray(l) ? l.filter(g => gecerli(g)) : []).sort((a, b) => a.an - b.an);
}
globalThis.bupAcikGiris = Object.freeze({
  ekle(json) {
    if (typeof json !== 'string' || json.length > 2000) throw new Error('acik-giris');
    const g = JSON.parse(json);
    if (!gecerli(g)) throw new Error('acik-giris');
    const l = liste().filter(x => x.girisId !== g.girisId);
    localStorage.setItem(ANAHTAR, JSON.stringify([...l, g].slice(-EN_FAZLA)));
    return 'ok';
  },
  temizle() {
    try { localStorage.removeItem(ANAHTAR); } catch { /* depo kapalıysa işaret zaten yok */ }
    return 'ok';
  },
  // sonuc.html kullanır; süresi geçmiş veya bozuk kayıtlar okunurken atılır.
  oku() {
    const l = liste();
    try { localStorage.setItem(ANAHTAR, JSON.stringify(l)); } catch { /* yalnız okuma */ }
    return l;
  },
});
