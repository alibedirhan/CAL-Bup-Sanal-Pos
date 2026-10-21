import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, webkit } from 'playwright';

// "BUP Doldur" yer imi uçtan uca: gerçek yer imi kodu, doldur sayfası, cihaz kasası ve
// bekleyen iş; ödeme sitesi yalnız yerel taklit (kullanıcı raporundaki alan adlarıyla).
const UYGULAMA = 'http://127.0.0.1:4191', POS = 'http://127.0.0.1:4199', BASKA = 'http://127.0.0.1:4198';
const kok = fileURLToPath(new URL('../../', import.meta.url));
const cikti = mkdtempSync(join(tmpdir(), 'bup-doldur-'));
execFileSync('python3', [join(kok, 'tools/yer_imi/uret.py'), '--uygulama', UYGULAMA, '--pos', POS, '--cikti', cikti]);
const yerImi = readFileSync(join(cikti, 'yer_imi_doldur.txt'), 'utf8');
assert.ok(yerImi.startsWith('javascript:') && !/[\s#]/.test(yerImi));
const kod = decodeURIComponent(yerImi.slice('javascript:'.length));
assert.ok(!kod.includes('denizpay') && !/[0-9]{12}/.test(kod), 'Yer iminde gerçek köken veya kart olmamalı');
const KART = '4111111111111111', SAHIBI = 'ÖRNEK KART SAHİBİ', KIMLIK = '0000000001';

const sayfa = (govde, baslik) => `<!doctype html><meta charset="utf-8"><title>${baslik}</title><body>${govde}</body>`;
// card.js benzeri: numara kutusu her girişte dörtlü gruplanır; gönderim kaydedilir.
const kartSayfasi = firma => sayfa(`<p>Firma İsmi : ÖRNEK YAPAY FİRMA (<a href="#">${firma}</a>)</p>
<form id="f" onsubmit="window.gonderildi=true;return false"><input name="name" id="name" placeholder="Full Name">
<input name="number" id="number" placeholder="•••• •••• •••• ••••"><input name="expiry" id="expiry" placeholder="MM/YY">
<input name="cvc" id="cvc" placeholder="CVC"><input name="Tutar" id="Tutar"><input type="submit" name="Button1" value="Öde"></form>
<script>document.getElementById('number').addEventListener('input',e=>{const d=e.target.value.replace(/\\D/g,'');e.target.value=d.replace(/(.{4})(?=.)/g,'$1 ');});
document.querySelector('[name=Button1]').addEventListener('click',()=>{window.tiklandi=true;});</script>`, 'Ödeme');
const statik = ad => readFileSync(join(kok, 'web', ad));
const sunucular = [
  [4191, yol => ({ '/doldur.html': ['text/html', statik('doldur.html')], '/kurulum.html': ['text/html', statik('kurulum.html')],
    '/doldurma.js': ['text/javascript', statik('doldurma.js')], '/kart_kasasi.js': ['text/javascript', statik('kart_kasasi.js')],
    '/doldur_sayfasi.js': ['text/javascript', readFileSync(join(cikti, 'doldur_sayfasi.js'))],
    '/kurulum.js': ['text/javascript', readFileSync(join(cikti, 'kurulum.js'))], '/bos': ['text/html', sayfa('', 'Uygulama')] })[yol]],
  [4199, yol => ({ '/index.aspx': ['text/html', kartSayfasi(KIMLIK)], '/baska.aspx': ['text/html', kartSayfasi('0000000009')],
    '/login.aspx': ['text/html', sayfa('<input name="lvergino"><input name="lsifre" type="password">', 'Giriş')] })[yol]],
  [4198, yol => yol === '/kotu' ? ['text/html', sayfa('kötü site', 'Kötü')] : undefined],
].map(([port, yanit]) => {
  const s = createServer((istek, cevap) => {
    const r = yanit(new URL(istek.url, 'http://x').pathname);
    if (!r) { cevap.writeHead(404); cevap.end(); return; }
    cevap.writeHead(200, { 'Content-Type': `${r[0]}; charset=utf-8`, 'Cache-Control': 'no-store' });
    cevap.end(r[1]);
  });
  s.listen(port, '127.0.0.1');
  return s;
});

// Uygulama kökeninde kartı kasaya şifreli yazar ve Dart'ın bırakacağı bekleyen işi kurar.
async function isKur(uygulama, son = 10 * 60 * 1000) {
  return uygulama.evaluate(async ({ KART, SAHIBI, KIMLIK, son }) => {
    await import('./kart_kasasi.js'); await import('./doldurma.js');
    const meta = { cariId: 'cari-1', id: 'kart-1', sonDort: KART.slice(-4), ay: 7, yil: 2032 };
    const h = JSON.parse(await bupKartKasasi.hazirla('uid-1', JSON.stringify(meta), JSON.stringify({ numara: KART, sahibi: SAHIBI, telefon: '' })));
    JSON.parse(await bupKartKasasi.tamamla('uid-1', h.value));
    const is = { v: 1, uid: 'uid-1', kimlikNo: KIMLIK, son: Date.now() + son, kart: { ...meta, cihazKayitId: h.value } };
    if (son > 0) bupDoldurma.hazirla(JSON.stringify(is)); else localStorage.setItem('bup-doldurma-isi', JSON.stringify(is));
    return localStorage.getItem('bup-doldurma-isi');
  }, { KART, SAHIBI, KIMLIK, son });
}
const degerler = pos => pos.evaluate(() => Object.fromEntries(['name', 'number', 'expiry', 'cvc', 'Tutar']
  .map(n => [n, document.getElementsByName(n)[0]?.value])));

try {
  for (const [ad, motor] of [['chromium', chromium], ['webkit', webkit]]) {
    const tarayici = await motor.launch();
    try {
      const baglam = await tarayici.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
      const harici = [];
      await baglam.route('**/*', route => {
        const o = new URL(route.request().url()).origin;
        if (![UYGULAMA, POS, BASKA].includes(o)) { harici.push(o); return route.abort(); }
        return route.continue();
      });
      const hatalar = [];
      baglam.on('page', p => p.on('pageerror', e => hatalar.push(String(e))));
      const uygulama = await baglam.newPage();
      await uygulama.goto(`${UYGULAMA}/kurulum.html`);
      assert.equal(await uygulama.locator('#kod').inputValue(), yerImi);
      const is = await isKur(uygulama);
      assert.ok(!is.includes(KART) && !is.includes(SAHIBI), 'Bekleyen işte kart/sahip olmamalı');

      // Doğru cari, kart sayfası: numara/ad/SKT yazılır; CVV, tutar ve düğmeye dokunulmaz.
      const pos = await baglam.newPage();
      await pos.goto(`${POS}/index.aspx`);
      await pos.locator('#Tutar').fill('987,65');
      const [acilan] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
      await acilan.waitForEvent('close', { timeout: 8000 });
      await pos.getByText(/Kart yazıldı \(•••• 1111\)/).waitFor({ timeout: 8000 });
      assert.deepEqual(await degerler(pos), { name: SAHIBI, number: '4111 1111 1111 1111', expiry: '07 / 32', cvc: '', Tutar: '987,65' });
      assert.deepEqual(await pos.evaluate(() => [window.gonderildi, window.tiklandi]), [undefined, undefined]);
      await pos.screenshot({ path: `/tmp/bup-pos-doldur-${ad}.png` });
      // Aynı iş 10 dakika içinde yeniden kullanılabilir (yanlış dokunuştan sonra tekrar).
      await pos.reload();
      const [ikinci] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
      await ikinci.waitForEvent('close', { timeout: 8000 });
      await pos.getByText(/Kart yazıldı/).waitFor({ timeout: 8000 });

      // Başka carinin DenizPay oturumu: hiçbir şey yazılmaz.
      await pos.goto(`${POS}/baska.aspx`);
      const [ucuncu] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
      await ucuncu.waitForEvent('close', { timeout: 8000 });
      await pos.getByText(/seçili cariye ait değil/).waitFor({ timeout: 8000 });
      assert.deepEqual(await degerler(pos), { name: '', number: '', expiry: '', cvc: '', Tutar: '' });

      // Giriş sayfası ve başka site: yer imi açılır pencere açmadan durur.
      let pencereSayisi = baglam.pages().length;
      await pos.goto(`${POS}/login.aspx`);
      await pos.evaluate(kod);
      await pos.getByText(/Kart kutuları bulunamadı/).waitFor();
      const kotu = await baglam.newPage();
      pencereSayisi++;
      await kotu.goto(`${BASKA}/kotu`);
      await kotu.evaluate(kod);
      await kotu.getByText(/yalnız DenizPay kart sayfasında/).waitFor();
      assert.equal(baglam.pages().length, pencereSayisi);

      // Kötü site doldur sayfasını kendisi açsa bile kart yalnız DenizPay kökenine gider.
      await kotu.evaluate(() => { window.gelen = []; addEventListener('message', e => window.gelen.push(e.data)); });
      const [k2] = await Promise.all([baglam.waitForEvent('page'),
        kotu.evaluate(u => { window.open(`${u}/doldur.html#b=${'a'.repeat(24)}`); }, UYGULAMA)]);
      await k2.getByText(/gönderildi|kapanıyor/).first().waitFor({ timeout: 8000 }).catch(() => {});
      await kotu.waitForTimeout(800);
      assert.deepEqual(await kotu.evaluate(() => window.gelen), []);

      // Süresi geçmiş iş: silinir, hiçbir şey yazılmaz.
      await isKur(uygulama, -1000);
      await pos.goto(`${POS}/index.aspx`);
      const [dorduncu] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
      await pos.getByText(/süre doldu/).waitFor({ timeout: 8000 });
      await dorduncu.close().catch(() => {});
      assert.equal(await degerler(pos).then(d => d.number), '');
      assert.equal(await uygulama.evaluate(() => localStorage.getItem('bup-doldurma-isi')), null);

      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await baglam.close();
      console.log(`PASS ${ad}: kart yazma, CVV/tutar/düğmeye dokunmama, firma eşleşmesi, köken reddi, süre, ağ yalıtımı`);
    } finally { await tarayici.close(); }
  }
} finally { for (const s of sunucular) s.close(); }
