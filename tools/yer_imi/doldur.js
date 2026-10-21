// Kart doldurma yer imi "BUP Doldur" (Aşama 2, docs/MOBIL_DOLDURMA_PLANI.md).
// Yalnız DenizPay kart sayfasında kart numarası, kart üzerindeki ad ve son
// kullanma kutularını yazar. CVV, tutar ve düğmelere dokunmaz; formu göndermez.
// Kart bilgisi yer iminde durmaz: Sanal POS'un doldur.html sayfası bu cihazdaki
// bekleyen işten okur ve yalnız DenizPay kökenine postMessage ile gönderir.
// Sayfadaki "Firma İsmi" numarası seçili carinin VKN/TC'si değilse hiçbir şey yazılmaz.
// Alan adları kullanıcının 21 Ekim iPhone raporundan: name, number, expiry, cvc, Tutar.
// Derleme: tam satır yorumlar silinir, satırlar birleştirilir (uret.py kuralları).
(() => {
const UYGULAMA = '__UYGULAMA_KOKENI__', POS = '__POS_KOKENI__', SURUM = 'doldur-1';
if (window.__bupDoldur) { window.__bupDoldur.kapat(); }
const kutu = document.createElement('div');
kutu.setAttribute('style', 'position:fixed;left:8px;right:8px;bottom:8px;z-index:2147483647;background:#fff;color:#111;border:3px solid #16343e;border-radius:12px;padding:12px;font:16px/1.4 -apple-system,system-ui,sans-serif;box-shadow:0 6px 24px rgba(0,0,0,.35)');
const yazi = document.createElement('p');
yazi.setAttribute('style', 'margin:0 0 10px');
const dugme = document.createElement('button');
dugme.type = 'button';
dugme.textContent = 'Kapat';
dugme.setAttribute('style', 'padding:10px 14px;font:600 15px system-ui,sans-serif;border-radius:8px;border:0;background:#16343e;color:#fff');
let dinle = null, zaman = null;
const kapat = () => {
  if (dinle) { window.removeEventListener('message', dinle); dinle = null; }
  clearTimeout(zaman);
  kutu.remove();
  window.__bupDoldur = null;
};
dugme.addEventListener('click', ev => { ev.preventDefault(); ev.stopPropagation(); kapat(); });
window.__bupDoldur = { kapat: kapat, surum: SURUM };
const goster = (mesaj, hata) => { yazi.textContent = 'BUP Doldur: ' + mesaj; kutu.style.borderColor = hata ? '#b3261e' : '#16343e'; };
kutu.append(yazi, dugme);
document.body.append(kutu);
if (location.origin !== POS) { goster('Bu yer imi yalnız DenizPay kart sayfasında çalışır.', true); return; }
const ENGEL = /tutar|amount|taksit|sms|otp|sifre|parola|password|cvv|cvc|csc|cv2|guvenlik|security|pin/i;
const alan = ad => {
  const l = Array.from(document.getElementsByName(ad)).filter(e => e.tagName === 'INPUT');
  if (l.length !== 1) { return null; }
  const e = l[0];
  const ipucu = [e.name, e.id, e.getAttribute('autocomplete'), e.placeholder, e.getAttribute('aria-label')].join(' ');
  if (!['text', 'tel'].includes(e.type) || e.disabled || e.readOnly || !e.getClientRects().length || ENGEL.test(ipucu)) { return null; }
  return e;
};
const k = { numara: alan('number'), ad: alan('name'), skt: alan('expiry') };
if (!k.numara || !k.skt) { goster('Kart kutuları bulunamadı. Kart numarasını yazdığın ödeme sayfasında dokun.', true); return; }
const firma = () => {
  const m = /Firma\s*[İI]smi\s*:?[^(\n]*\(\s*([0-9]{10,11})\s*\)/.exec(document.body.innerText);
  return m ? m[1] : null;
};
if (!firma()) { goster('Sayfada firma numarası bulunamadı; güvenlik için kart yazılmadı.', true); return; }
const id = Array.from(crypto.getRandomValues(new Uint8Array(12)), b => b.toString(16).padStart(2, '0')).join('');
const pencere = window.open(UYGULAMA + '/doldur.html#b=' + id, '_blank');
if (!pencere) { goster('Açılır pencere engellendi. Tarayıcı ayarında açılır pencerelere izin ver.', true); return; }
goster('Sanal POS’tan kart bekleniyor. Açılan sekme kapanmazsa bu sekmeye dön.', false);
const luhn = n => {
  let t = 0, cift = false;
  for (let i = n.length - 1; i >= 0; i--, cift = !cift) { let r = Number(n[i]); if (cift) { r *= 2; if (r > 9) { r -= 9; } } t += r; }
  return t > 0 && t / 10 === Math.floor(t / 10);
};
const grupla = n => {
  const boy = /^3[47]/.test(n) ? [4, 6, 5] : [4, 4, 4, 4, 3];
  const p = [];
  let i = 0;
  for (const b of boy) { if (i < n.length) { p.push(n.slice(i, i + b)); i += b; } }
  return p.join(' ');
};
const yaz = (e, v) => {
  const ayar = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  e.focus();
  ayar.call(e, v);
  for (const t of ['input', 'change', 'keyup']) { e.dispatchEvent(new Event(t, { bubbles: true })); }
  e.blur();
};
dinle = e => {
  if (e.source !== pencere || e.origin !== UYGULAMA || !e.data || e.data.tur !== 'bup-doldur-paket' || e.data.id !== id) { return; }
  window.removeEventListener('message', dinle);
  dinle = null;
  clearTimeout(zaman);
  if (typeof e.data.hata === 'string') { goster(e.data.hata.slice(0, 300), true); return; }
  const c = e.data.kart || {};
  const gecerli = typeof c.numara === 'string' && /^[0-9]{12,19}$/.test(c.numara) && luhn(c.numara) &&
    Number.isInteger(c.ay) && c.ay >= 1 && c.ay <= 12 && Number.isInteger(c.yil) && c.yil >= 2000 && c.yil <= 2199 &&
    typeof c.ad === 'string' && c.ad.length <= 120 && !/[\x00-\x1f]/.test(c.ad) &&
    typeof c.kimlikNo === 'string' && /^[0-9]{10,11}$/.test(c.kimlikNo);
  if (!gecerli) { goster('Gelen kart bilgisi geçersiz; hiçbir şey yazılmadı.', true); return; }
  if (firma() !== c.kimlikNo) { goster('Bu DenizPay oturumu seçili cariye ait değil. Kart yazılmadı. Sanal POS’tan doğru cariyle giriş yap.', true); return; }
  yaz(k.numara, grupla(c.numara));
  if (k.ad && c.ad) { yaz(k.ad, c.ad); }
  yaz(k.skt, String(c.ay).padStart(2, '0') + ' / ' + String(c.yil).slice(-2));
  const tamam = k.numara.value.replace(/[^0-9]/g, '') === c.numara;
  goster(tamam ? 'Kart yazıldı (•••• ' + c.numara.slice(-4) + '). Şimdi CVV ve tutarı yaz, ödemeyi sen onayla.' : 'Kart numarası kutuya tam yazılamadı; kontrol et veya elle yaz.', !tamam);
};
window.addEventListener('message', dinle);
zaman = setTimeout(() => { if (dinle) { window.removeEventListener('message', dinle); dinle = null; goster('Sanal POS’tan yanıt gelmedi. Yer imine yeniden dokun.', true); } }, 120000);
})();
