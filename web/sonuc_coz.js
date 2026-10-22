// DenizPay sonuç ekranının ("Onay Formu" / "Hata Formu") okunması. Saf işlevler:
// ağ, depo, sayfa yok. tutarCoz'un Dart karşılığı lib/domain/tahsilat.dart'tadır;
// ikisi de test/veri/tahsilat_ornekleri.json örnekleriyle sınanır.
// Ekran (kullanıcı görüntüleri, 22 Ekim): Açıklama, Üye Sipariş Numarası (yalnız
// başarılıda), Pos Sipariş Numarası ("VP…"), Tutar ("4500", "45678,90").

// Virgül kuruş, nokta binlik ayracı; tek nokta + 1–2 hane kuruş sayılır. Emin değilse null.
export function tutarCoz(metin) {
  if (typeof metin !== 'string') return null;
  const t = metin.replace(/(TL|TRY|₺)/gi, '').replace(/[\s ]/g, '');
  const binlik = /^[0-9]{1,3}(\.[0-9]{3})+$/;
  let tam, kurus = '';
  if (/^[0-9.]+,[0-9]{1,2}$/.test(t)) {
    const p = t.split(',');
    if (p[0].includes('.') && !binlik.test(p[0])) return null;
    tam = p[0].replace(/\./g, '');
    kurus = p[1];
  } else if (binlik.test(t)) {
    tam = t.replace(/\./g, '');
  } else if (/^[0-9]+\.[0-9]{1,2}$/.test(t)) {
    [tam, kurus] = t.split('.');
  } else if (/^[0-9]+$/.test(t)) {
    tam = t;
  } else {
    return null;
  }
  if (!tam || tam.length > 10) return null;
  return Number(tam) * 100 + Number(kurus.padEnd(2, '0'));
}

// 450000 → "4.500,00 TL"
export function tutarYaz(kurus) {
  const tl = String(Math.floor(kurus / 100)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return tl + ',' + String(kurus % 100).padStart(2, '0') + ' TL';
}

export const duz = v => String(v ?? '').replace(/\s+/g, ' ').trim();
// Türkçe büyük/küçük harf ve klavye farkını yok sayan karşılaştırma anahtarı.
const anahtar = v => duz(v).replace(/[İIı]/g, 'i').toLowerCase().replace(/ş/g, 's').replace(/ğ/g, 'g')
  .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c').replace(/\s*:$/, '');
const ETIKET = { aciklama: 'aciklama', uye: 'uye siparis numarasi', pos: 'pos siparis numarasi', tutar: 'tutar' };
const ETIKETLER = new Set(Object.values(ETIKET));
const KONTROL = /[\x00-\x1f\x7f]/;

// Yer iminin gönderdiği sayfa özeti biçimce geçerli mi (başka bir şey işlenmez).
export function sayfaGecerli(s) {
  return !!s && typeof s === 'object' && typeof s.metin === 'string' && s.metin.length <= 5000 &&
    Array.isArray(s.alanlar) && s.alanlar.length <= 40 &&
    s.alanlar.every(a => Array.isArray(a) && a.length === 2 && typeof a[0] === 'string' && a[0].length <= 80 &&
      typeof a[1] === 'string' && a[1].length <= 200) &&
    (s.firma === null || (typeof s.firma === 'string' && /^[0-9]{10,11}$/.test(s.firma)));
}

// Önce etiketli kutular; kutu yoksa sayfa yazısında etiketten sonraki satır.
function alan(sayfa, etiket) {
  const bulunan = sayfa.alanlar.filter(([e]) => anahtar(e) === etiket).map(([, d]) => duz(d)).filter(Boolean);
  if (bulunan.length === 1) return bulunan[0];
  if (bulunan.length > 1) return null;
  const satirlar = sayfa.metin.split('\n').map(duz).filter(Boolean);
  const i = satirlar.findIndex(s => anahtar(s) === etiket);
  if (i < 0 || satirlar.findIndex((s, j) => j > i && anahtar(s) === etiket) >= 0) return null;
  const sonraki = satirlar[i + 1];
  return sonraki && !ETIKETLER.has(anahtar(sonraki)) ? sonraki : null;
}

const hata = mesaj => ({ ok: false, hata: mesaj });

// Sonuç ekranını kayda çevirir. Belirsizlikte kaydetmez, nedenini söyler.
export function sonucCoz(sayfa) {
  if (!sayfaGecerli(sayfa)) return hata('Sayfa okunamadı. Sonucu Sanal POS’ta elle kaydet.');
  const metin = anahtar(sayfa.metin);
  const onay = /\bonay formu\b/.test(metin), hataFormu = /\bhata formu\b/.test(metin);
  if (onay === hataFormu) {
    return hata('Bu sayfa DenizPay sonuç ekranı (Onay Formu / Hata Formu) değil. Ödeme bitince sonuç ekranında dokun.');
  }
  const aciklama = alan(sayfa, ETIKET.aciklama);
  const pos = duz(alan(sayfa, ETIKET.pos)).replace(/\s/g, '').toUpperCase();
  const tutarMetni = alan(sayfa, ETIKET.tutar);
  const uye = onay ? alan(sayfa, ETIKET.uye) ?? '' : '';
  if (!/^[A-Z0-9_-]{4,64}$/.test(pos)) return hata('Pos Sipariş Numarası okunamadı. Sonucu elle kaydet.');
  if (!tutarMetni || tutarMetni.length > 40 || KONTROL.test(tutarMetni)) return hata('Tutar okunamadı. Sonucu elle kaydet.');
  if (!aciklama || aciklama.length > 200 || KONTROL.test(aciklama)) return hata('Açıklama okunamadı. Sonucu elle kaydet.');
  if (uye.length > 40) return hata('Üye Sipariş Numarası okunamadı. Sonucu elle kaydet.');
  // "Onay Formu" yalnız açıklama da başarıyı söylüyorsa başarılı sayılır.
  if (onay && !/basari/.test(anahtar(aciklama))) {
    return hata('Ödeme sonucu anlaşılamadı (' + aciklama.slice(0, 80) + '). DenizPay’de kontrol edip elle kaydet.');
  }
  return {
    ok: true,
    sonuc: onay ? 'basarili' : 'hata',
    aciklama,
    posSiparisNo: pos,
    uyeSiparisNo: uye,
    tutarMetni,
    tutarKurus: tutarCoz(tutarMetni),
  };
}
