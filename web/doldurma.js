// Kart sayfası yer imi için bekleyen işi bu kökenin yerel deposuna yazar.
// İşte tam kart, CVV, tutar veya giriş şifresi yoktur; yalnız cihaz kasası
// referansı, cari VKN/TC'si ve son geçerlilik zamanı (en çok 10 dakika).
const ANAHTAR = 'bup-doldurma-isi';
const SURE = 10 * 60 * 1000;
const metin = (v, en) => typeof v === 'string' && v.length > 0 && v.length <= en && !/[\x00-\x1f]/.test(v);
function gecerli(is) {
  const k = is?.kart;
  return is && Object.keys(is).sort().join(',') === 'kart,kimlikNo,son,uid,v' && is.v === 1 &&
    metin(is.uid, 128) && /^[0-9]{10,11}$/.test(is.kimlikNo) && Number.isInteger(is.son) &&
    is.son > Date.now() && is.son - Date.now() <= SURE + 5000 && k &&
    Object.keys(k).sort().join(',') === 'ay,cariId,cihazKayitId,id,sonDort,yil' &&
    metin(k.id, 128) && metin(k.cariId, 128) && metin(k.cihazKayitId, 128) && /^[0-9]{4}$/.test(k.sonDort) &&
    Number.isInteger(k.ay) && k.ay >= 1 && k.ay <= 12 && Number.isInteger(k.yil) && k.yil >= 2000 && k.yil <= 2199;
}
globalThis.bupDoldurma = Object.freeze({
  hazirla(json) {
    if (typeof json !== 'string' || json.length > 2000 || !gecerli(JSON.parse(json))) throw new Error('doldurma');
    localStorage.setItem(ANAHTAR, json);
    return 'ok';
  },
  temizle() {
    try { localStorage.removeItem(ANAHTAR); } catch { /* depo kapalıysa iş zaten yok */ }
    return 'ok';
  },
  // doldur.html aynı denetimi kullanır; süresi geçmiş veya bozuk iş silinir.
  oku() {
    let is = null;
    try { is = JSON.parse(localStorage.getItem(ANAHTAR) ?? 'null'); } catch { is = null; }
    if (gecerli(is)) return is;
    try { localStorage.removeItem(ANAHTAR); } catch { /* yok */ }
    return null;
  },
});
