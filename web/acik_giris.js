// Bu cihazda son açılan DenizPay girişini bu kökenin yerel deposunda tutar
// (lib/domain/acik_giris.dart). DenizPay sonuç ekranındaki "BUP Doldur" yer
// iminin açtığı sonuc.html sonucu bu cariye bağlar. Sır yoktur: kart numarası,
// şifre, CVV, tutar bulunmaz; yalnız cari adı/VKN, kartın son dört hanesi.
const ANAHTAR = 'bup-acik-giris';
const SURE = 2 * 60 * 60 * 1000;
const metin = (v, en) => typeof v === 'string' && v.length > 0 && v.length <= en && !/[\x00-\x1f\x7f]/.test(v);
function gecerli(g) {
  return g && Object.keys(g).sort().join(',') === 'cariAd,cariId,girisId,kartSonDort,kimlikNo,son,uid,v' && g.v === 1 &&
    metin(g.uid, 128) && /^[A-Za-z0-9]{20}$/.test(g.girisId) && metin(g.cariId, 128) && metin(g.cariAd, 80) &&
    /^[0-9]{10,11}$/.test(g.kimlikNo) && /^([0-9]{4})?$/.test(g.kartSonDort) &&
    Number.isInteger(g.son) && g.son > Date.now() && g.son - Date.now() <= SURE + 5000;
}
globalThis.bupAcikGiris = Object.freeze({
  hazirla(json) {
    if (typeof json !== 'string' || json.length > 2000 || !gecerli(JSON.parse(json))) throw new Error('acik-giris');
    localStorage.setItem(ANAHTAR, json);
    return 'ok';
  },
  temizle() {
    try { localStorage.removeItem(ANAHTAR); } catch { /* depo kapalıysa işaret zaten yok */ }
    return 'ok';
  },
  // sonuc.html aynı denetimi kullanır; süresi geçmiş veya bozuk işaret silinir.
  oku() {
    let g = null;
    try { g = JSON.parse(localStorage.getItem(ANAHTAR) ?? 'null'); } catch { g = null; }
    if (gecerli(g)) return g;
    try { localStorage.removeItem(ANAHTAR); } catch { /* yok */ }
    return null;
  },
});
