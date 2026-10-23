// DenizPay sonuç ekranından okunan, Sanal POS'un henüz sunucuya yazmadığı
// sonuçlar (bu kökenin yerel deposu). sonuc.html ekler; oturumu açık Sanal POS
// sekmesi (lib/data/sonuc_kutusu_web.dart) okur, posIslemleri'ne yazar, siler ve
// "bup-sonuc-yanit" ile sonucu bildirir. Oturum yalnız o sekmede olduğu için
// (Persistence.SESSION) sunucuya yazma burada yapılmaz. Kart bilgisi yoktur.
const KUTU = 'bup-sonuc-kutusu', YANIT = 'bup-sonuc-yanit';
// Ödeme sonucu değerlidir: Sanal POS uzun süre açılmasa da 30 gün bekler (kural da
// 31 güne kadar kabul eder). 1: 0.9.0 sonuç sayfası; 2: cari eşleşmesiyle (0.10.0).
const SURE = 30 * 24 * 60 * 60 * 1000, EN_FAZLA = 20;
const ALANLAR = 'aciklama,cariAd,cariId,girisId,kartSonDort,kimlikNo,okunma,posSiparisNo,sonuc,tutarMetni,uid,uyeSiparisNo,v';
const ESLESME = ['sonuc_ekrani', 'kart_sayfasi', 'tek_giris', 'secim'];
// Denetim Dart'taki (lib/domain/modeller.dart duzMetin) kadar sıkıdır: burada kabul edilen
// sonuç Sanal POS'ta okunamayıp beklemede kalmasın. Görünmez işaretleri sonuc_coz.js atar.
const metin = (v, en, bos = false) => typeof v === 'string' && (bos || v.length > 0) && v.length <= en &&
  !/[\x00-\x1f\x7f\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]/.test(v) && (bos || v.trim().length > 0);
// Bir ödeme denemesinin kimliği (lib/domain/tahsilat.dart belgeKimligi, firestore.rules): başarılıda
// Pos Sipariş No, başarısızda sonuna "-h". Başarısız denemeden sonra aynı numarayla gelen başarılı
// sonuç ayrı tutulur; aynı sonucun ikinci kez eklenmesi engellenir.
export const kimlik = s => s.posSiparisNo + (s.sonuc === 'hata' ? '-h' : '');
export function gecerli(s) {
  const surum = s?.v === 1 ? Object.keys(s).sort().join(',') === ALANLAR
    : s?.v === 2 && Object.keys(s).filter(k => k !== 'eslesme').sort().join(',') === ALANLAR && ESLESME.includes(s.eslesme);
  return !!s && typeof s === 'object' && surum &&
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
  // Aynı kimlik (numara + sonuç) ikinci kez eklenmez.
  ekle(json) {
    const s = JSON.parse(json);
    if (!gecerli(s)) throw new Error('sonuc');
    const l = liste();
    if (l.some(x => kimlik(x) === kimlik(s))) return 'zaten';
    yaz([...l, s]);
    return 'ok';
  },
  oku() { return JSON.stringify(liste()); },
  // Sonuç sayfası: bu kimlik daha önce hangi cari ve tutarla alındı.
  bul(k) { return liste().find(x => kimlik(x) === k) ?? null; },
  sil(k) {
    try { yaz(liste().filter(x => kimlik(x) !== k)); } catch { /* depo kapalı */ }
    return 'ok';
  },
  yanitla(json) { localStorage.setItem(YANIT, json); return 'ok'; },
  // Başka sekmede eklenen sonuç (storage olayı yalnız diğer sekmelere gelir).
  dinle(geri) { addEventListener('storage', e => { if (e.key === KUTU && e.newValue) geri(); }); return 'ok'; },
  yanitDinle(geri) { addEventListener('storage', e => { if (e.key === YANIT && e.newValue) geri(e.newValue); }); return 'ok'; },
});
