// DenizPay sonuç ekranından okunan, Sanal POS'un henüz sunucuya yazmadığı
// sonuçlar (bu kökenin yerel deposu). sonuc.html ekler; oturumu açık Sanal POS
// sekmesi (lib/data/sonuc_kutusu_web.dart) okur, posIslemleri'ne yazar, siler ve
// "bup-sonuc-yanit" ile sonucu bildirir. Oturum yalnız o sekmede olduğu için
// (Persistence.SESSION) sunucuya yazma burada yapılmaz. Kart bilgisi yoktur.
const KUTU = 'bup-sonuc-kutusu', YANIT = 'bup-sonuc-yanit';
const SURE = 48 * 60 * 60 * 1000, EN_FAZLA = 20;
const ALANLAR = 'aciklama,cariAd,cariId,girisId,kartSonDort,kimlikNo,okunma,posSiparisNo,sonuc,tutarMetni,uid,uyeSiparisNo,v';
const metin = (v, en, bos = false) => typeof v === 'string' && (bos || v.length > 0) && v.length <= en && !/[\x00-\x1f\x7f]/.test(v);
export function gecerli(s) {
  return !!s && typeof s === 'object' && Object.keys(s).sort().join(',') === ALANLAR && s.v === 1 &&
    metin(s.uid, 128) && /^[A-Za-z0-9]{20}$/.test(s.girisId) && metin(s.cariId, 128) && metin(s.cariAd, 80) &&
    /^[0-9]{10,11}$/.test(s.kimlikNo) && /^([0-9]{4})?$/.test(s.kartSonDort) && ['basarili', 'hata'].includes(s.sonuc) &&
    metin(s.aciklama, 200) && /^[A-Z0-9_-]{4,64}$/.test(s.posSiparisNo) && metin(s.uyeSiparisNo, 40, true) &&
    metin(s.tutarMetni, 40) && Number.isInteger(s.okunma) && s.okunma <= Date.now() + 60000 && Date.now() - s.okunma < SURE;
}
function liste() {
  let l = [];
  try { l = JSON.parse(localStorage.getItem(KUTU) ?? '[]'); } catch { l = []; }
  return Array.isArray(l) ? l.filter(gecerli) : [];
}
const yaz = l => localStorage.setItem(KUTU, JSON.stringify(l.slice(-EN_FAZLA)));
globalThis.bupSonucKutusu = Object.freeze({
  // Aynı Pos Sipariş Numarası ikinci kez eklenmez.
  ekle(json) {
    const s = JSON.parse(json);
    if (!gecerli(s)) throw new Error('sonuc');
    const l = liste();
    if (l.some(x => x.posSiparisNo === s.posSiparisNo)) return 'zaten';
    yaz([...l, s]);
    return 'ok';
  },
  oku() { return JSON.stringify(liste()); },
  sil(posSiparisNo) {
    try { yaz(liste().filter(x => x.posSiparisNo !== posSiparisNo)); } catch { /* depo kapalı */ }
    return 'ok';
  },
  yanitla(json) { localStorage.setItem(YANIT, json); return 'ok'; },
  // Başka sekmede eklenen sonuç (storage olayı yalnız diğer sekmelere gelir).
  dinle(geri) { addEventListener('storage', e => { if (e.key === KUTU && e.newValue) geri(); }); return 'ok'; },
  yanitDinle(geri) { addEventListener('storage', e => { if (e.key === YANIT && e.newValue) geri(e.newValue); }); return 'ok'; },
});
