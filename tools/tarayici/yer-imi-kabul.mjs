import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, webkit } from 'playwright';

// Deneme yer imi: yalnız yerel kökenler, yapay ödeme sayfası. Gerçek POS'a istek yoktur.
const UYGULAMA = 'http://127.0.0.1:4191', POS = 'http://127.0.0.1:4199', BASKA = 'http://127.0.0.1:4198';
const kok = fileURLToPath(new URL('../../', import.meta.url));
const cikti = mkdtempSync(join(tmpdir(), 'bup-yer-imi-'));
execFileSync('python3', [join(kok, 'tools/yer_imi/uret.py'), '--uygulama', UYGULAMA, '--pos', POS, '--cikti', cikti]);
const yerImi = readFileSync(join(cikti, 'yer_imi_deneme.txt'), 'utf8');
assert.ok(yerImi.startsWith('javascript:'));
assert.ok(!/[\s#]/.test(yerImi), 'Yer imi adresi boşluk/# içermemeli');
const kod = decodeURIComponent(yerImi.slice('javascript:'.length));
assert.ok(!kod.includes('denizpay'), 'Test yer imi gerçek POS kökeni içermemeli');

const sayfa = (govde, baslik = 'Yapay') => `<!doctype html><meta charset="utf-8"><title>${baslik}</title><body>${govde}</body>`;
const odeme = sayfa(`<form><table>
<tr><td>Kredi Kartı Numarası</td><td><input name="ctl00$txtKartNo" id="txtKartNo" maxlength="16"></td></tr>
<tr><td>Kart Üzerindeki İsim</td><td><input name="ctl00$txtAd" id="txtAd"></td></tr>
<tr><td>S.K.T</td><td><select name="ctl00$ddlAy"><option>01</option></select><select name="ctl00$ddlYil"><option>2030</option></select></td></tr>
<tr><td>CVV</td><td><input name="ctl00$txtCvv" maxlength="3"></td></tr>
<tr><td>Tutar</td><td><input name="ctl00$txtTutar"></td></tr>
<tr><td>Firma 1234567890</td><td><input type="hidden" name="gizli" value="5555"></td></tr>
</table><iframe src="${BASKA}/cerceve"></iframe></form>`, 'Ödeme');
const giris = sayfa(`<form id="form1"><input id="lvergino" name="lvergino"><input id="lkullaniciadi" name="lkullaniciadi">
<input id="lsifre" name="lsifre" type="password"><input type="submit" name="btngiris" value="Giriş Yap"></form>`, 'Giriş');

const sunucular = [
  [4191, (yol) => yol === '/deneme.html' ? ['text/html', readFileSync(join(kok, 'web/deneme.html'))]
    : yol === '/deneme.js' ? ['text/javascript', readFileSync(join(cikti, 'deneme.js'))] : null],
  [4199, (yol) => yol === '/login.aspx' ? ['text/html', giris] : yol === '/odeme.aspx' ? ['text/html', odeme] : null],
  [4198, (yol) => yol === '/cerceve' ? ['text/html', sayfa('çerçeve')]
    : yol === '/kotu' ? ['text/html', sayfa('kötü site')] : null],
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
      const uygulama = await baglam.newPage();
      const hatalar = [];
      uygulama.on('pageerror', e => hatalar.push(String(e)));
      await uygulama.goto(`${UYGULAMA}/deneme.html`);
      assert.equal(await uygulama.locator('#kod').inputValue(), yerImi);
      assert.equal(await uygulama.locator('#kip').textContent(), 'tarayıcı sekmesi');

      // A kanalı: uygulama ödeme sitesini açar, kullanıcı aynı sekmede ödeme sayfasına geçer.
      const [pos] = await Promise.all([uygulama.waitForEvent('popup'), uygulama.locator('#ac').click()]);
      pos.on('pageerror', e => hatalar.push(String(e)));
      await pos.waitForURL(`${POS}/login.aspx`);
      await pos.goto(`${POS}/odeme.aspx`);
      // Kullanıcının yazdığı değerler raporda görünmemeli ve değişmemeli.
      await pos.locator('#txtKartNo').fill('4111111111111111');
      await pos.locator('[name="ctl00$txtTutar"]').fill('987,65');
      await pos.evaluate(kod);
      const kutu = pos.locator('pre');
      await assert.doesNotReject(kutu.filter({ hasText: 'A kanalı: çalıştı' }).waitFor({ timeout: 5000 }));
      assert.equal(await uygulama.locator('#a-durum').textContent(), 'Yer iminden mesaj geldi ve yanıtlandı');

      // B kanalı: yer imi Sanal POS'u açar; açılan sayfa yanıtlayıp kendini kapatır.
      const [geri] = await Promise.all([pos.waitForEvent('popup'), pos.getByRole('button', { name: 'B kanalını dene' }).click()]);
      await kutu.filter({ hasText: 'B kanalı: çalıştı' }).waitFor({ timeout: 5000 });
      await geri.waitForEvent('close', { timeout: 5000 });

      const rapor = await kutu.textContent();
      for (const yok of ['4111', '987', '1234567890', '5555', 'gizli']) assert.ok(!rapor.includes(yok), `Raporda ${yok} olmamalı`);
      for (const var_ of ['Sayfa: DenizPay /odeme.aspx', 'txtKartNo', 'Kredi Kartı Numarası', 'ctl##$txtKartNo',
        'Çerçeveler (1): ' + BASKA.replace(/[0-9]/g, '#'), 'Alanlar (6):']) {
        assert.ok(rapor.includes(var_), `Raporda ${var_} olmalı:\n${rapor}`);
      }
      assert.equal(await pos.locator('#txtKartNo').inputValue(), '4111111111111111');
      assert.equal(await pos.locator('#txtAd').inputValue(), '');
      assert.equal(await pos.locator('[name="ctl00$txtCvv"]').inputValue(), '');
      assert.equal(await pos.locator('[name="ctl00$txtTutar"]').inputValue(), '987,65');

      // Başka köken: B yanıtı yalnız POS kökenine gider; kötü sayfa mesaj alamaz.
      const kotu = await baglam.newPage();
      await kotu.goto(`${BASKA}/kotu`);
      await kotu.evaluate(() => { window.gelen = []; addEventListener('message', e => window.gelen.push(e.data)); });
      const [k2] = await Promise.all([kotu.waitForEvent('popup'),
        kotu.evaluate(u => { window.open(`${u}/deneme.html#b=${'a'.repeat(24)}`); }, UYGULAMA)]);
      await k2.locator('#b-durum').filter({ hasText: 'Yanıt gönderildi' }).waitFor();
      await kotu.waitForTimeout(500);
      assert.deepEqual(await kotu.evaluate(() => window.gelen), []);
      // Uygulama, kendi açmadığı pencereden gelen merhabayı yanıtlamaz.
      await kotu.evaluate(() => window.gelen = []);
      const [k3] = await Promise.all([kotu.waitForEvent('popup'),
        kotu.evaluate(u => { window.k3 = window.open(`${u}/deneme.html`); }, UYGULAMA)]);
      await k3.waitForLoadState();
      await kotu.evaluate(u => window.k3.postMessage({ tur: 'bup-deneme-merhaba', id: 'b'.repeat(24) }, u), UYGULAMA);
      await kotu.waitForTimeout(500);
      assert.deepEqual(await kotu.evaluate(() => window.gelen), []);
      assert.equal(await k3.locator('#a-durum').textContent(), 'DenizPay henüz açılmadı');

      // Yer imi başka sitede çalışırsa yalnız durum gösterir; sayfayı değiştirmez.
      await kotu.evaluate(kod);
      await kotu.locator('pre').filter({ hasText: 'Sayfa: başka site' }).waitFor();
      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await uygulama.screenshot({ path: `/tmp/bup-pos-yer-imi-${ad}-uygulama.png`, fullPage: true });
      await pos.screenshot({ path: `/tmp/bup-pos-yer-imi-${ad}-pos.png` });
      await baglam.close();
      console.log(`PASS ${ad}: A ve B kanalı, değer okumayan rapor, alanlara dokunmama, köken reddi, ağ yalıtımı`);
    } finally { await tarayici.close(); }
  }
} finally { for (const s of sunucular) s.close(); }
