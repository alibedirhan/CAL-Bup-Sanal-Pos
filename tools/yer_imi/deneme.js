// Telefon uyumluluk denemesi yer imi (Aşama 0, docs/MOBIL_DOLDURMA_PLANI.md).
// Hiçbir alanı doldurmaz, alan değeri okumaz, ağ isteği yapmaz, depoya yazmaz.
// Yalnız Sanal POS kökenine kişisel bilgi içermeyen deneme mesajı yollar.
// Derleme: tam satır yorumlar silinir, satırlar birleştirilir. Bu yüzden satır
// sonu yorumu, yüzde işareti ve çok satırlı metin kullanılmaz.
(() => {
const UYGULAMA = '__UYGULAMA_KOKENI__', POS = '__POS_KOKENI__', SURUM = 'deneme-1';
if (window.__bupDeneme) { window.__bupDeneme.remove(); }
const id = Array.from(crypto.getRandomValues(new Uint8Array(12)), b => b.toString(16).padStart(2, '0')).join('');
const kisa = v => String(v == null ? '' : v).replace(/[0-9]/g, '#').replace(/\s+/g, ' ').trim().slice(0, 40);
let acan = null;
try { acan = window.opener; } catch (e) { acan = null; }
let pencere = null;
const ua = navigator.userAgent;
const r = {
  surum: SURUM,
  sayfa: location.origin === POS ? 'DenizPay' : 'başka site',
  yol: kisa(location.pathname),
  cihaz: /iPhone|iPad/.test(ua) ? 'iPhone/iPad' : /Android/.test(ua) ? 'Android' : 'diğer',
  tarayici: /CriOS/.test(ua) ? 'Chrome iOS' : /SamsungBrowser/.test(ua) ? 'Samsung' : /Chrome/.test(ua) ? 'Chrome' : /Safari/.test(ua) ? 'Safari' : 'diğer',
  acan: acan ? 'var' : 'yok',
  a: acan ? 'bekleniyor' : 'denenemedi (açan sekme yok)',
  b: 'denenmedi'
};
const gorunur = el => el.type !== 'hidden' && el.getClientRects().length > 0;
const baslik = el => {
  const l = el.labels && el.labels[0] ? el.labels[0].textContent : '';
  const td = el.closest('td');
  const once = td && td.previousElementSibling ? td.previousElementSibling.textContent : '';
  return kisa(l || el.getAttribute('aria-label') || el.placeholder || el.title || once);
};
const alanlar = Array.from(document.querySelectorAll('input,select,textarea')).filter(gorunur).slice(0, 40)
  .map(el => [el.tagName.toLowerCase(), el.type || '', el.name, el.id, el.autocomplete, el.maxLength > 0 ? el.maxLength : '', baslik(el)].map(kisa).join(' | '));
const cerceveler = Array.from(document.querySelectorAll('iframe')).slice(0, 10).map(f => {
  try { return kisa(new URL(f.src, location.href).origin); } catch (e) { return 'adres yok'; }
});
const kutu = document.createElement('div');
window.__bupDeneme = kutu;
kutu.setAttribute('style', 'position:fixed;left:8px;right:8px;bottom:8px;max-height:70vh;overflow:auto;z-index:2147483647;background:#fff;color:#111;border:3px solid #16343e;border-radius:12px;padding:12px;font:14px/1.4 -apple-system,system-ui,sans-serif;box-shadow:0 6px 24px rgba(0,0,0,.35)');
const metin = () => [
  'BUP Sanal POS deneme (' + r.surum + ')',
  'Sayfa: ' + r.sayfa + ' ' + r.yol,
  'Cihaz: ' + r.cihaz + ', ' + r.tarayici,
  'Açan sekme: ' + r.acan,
  'A kanalı: ' + r.a,
  'B kanalı: ' + r.b,
  'Çerçeveler (' + cerceveler.length + '): ' + (cerceveler.join(', ') || '-'),
  'Alanlar (' + alanlar.length + '):'
].concat(alanlar).join('\n');
const yazi = document.createElement('pre');
yazi.setAttribute('style', 'white-space:pre-wrap;word-break:break-word;margin:0 0 10px;font:13px/1.35 ui-monospace,Menlo,monospace');
const dugme = (ad, is) => {
  const d = document.createElement('button');
  d.type = 'button';
  d.textContent = ad;
  d.setAttribute('style', 'margin:4px 6px 0 0;padding:10px 12px;font:600 14px system-ui,sans-serif;border-radius:8px;border:1px solid #16343e;background:#16343e;color:#fff');
  d.addEventListener('click', ev => { ev.preventDefault(); ev.stopPropagation(); is(d); });
  return d;
};
const ciz = () => { yazi.textContent = metin(); };
const bDugme = dugme('B kanalını dene', () => {
  pencere = window.open(UYGULAMA + '/deneme.html#b=' + id, '_blank');
  r.b = pencere ? 'bekleniyor (açılan sayfadan bu sekmeye dönün)' : 'açılır pencere engellendi';
  ciz();
});
const kopya = dugme('Raporu kopyala', d => {
  const t = metin();
  const bitti = () => { d.textContent = 'Kopyalandı'; };
  const elle = () => {
    const alan = document.createElement('textarea');
    alan.value = t;
    alan.setAttribute('style', 'width:calc(100vw - 48px);height:8em');
    kutu.append(alan);
    alan.select();
    d.textContent = 'Seçili metni kopyalayın';
  };
  try { navigator.clipboard.writeText(t).then(bitti, elle); } catch (e) { elle(); }
});
const kapat = dugme('Kapat', () => { window.removeEventListener('message', dinle); kutu.remove(); window.__bupDeneme = null; });
const dinle = e => {
  if (e.origin !== UYGULAMA || !e.data || e.data.tur !== 'bup-deneme-yanit' || e.data.id !== id) { return; }
  if (acan && e.source === acan && e.data.kanal === 'A') { r.a = 'çalıştı'; }
  if (pencere && e.source === pencere && e.data.kanal === 'B') { r.b = 'çalıştı'; }
  ciz();
};
window.addEventListener('message', dinle);
kutu.append(yazi, bDugme, kopya, kapat);
document.body.append(kutu);
ciz();
if (acan) {
  try { acan.postMessage({ tur: 'bup-deneme-merhaba', id: id, surum: SURUM }, UYGULAMA); } catch (e) { r.a = 'mesaj gönderilemedi'; }
  setTimeout(() => { if (r.a === 'bekleniyor') { r.a = 'yanıt gelmedi'; ciz(); } }, 5000);
}
})();
