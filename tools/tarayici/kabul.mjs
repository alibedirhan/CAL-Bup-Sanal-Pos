import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { chromium, webkit } from 'playwright';

// Yalnız yerel derleme; bütün harici ağ istekleri engellenir.
const origin = 'http://127.0.0.1:4195';
const output = '/tmp/bup-pos-qa';
await mkdir(output, { recursive: true });
const cases = [
  { name: 'chromium-telefon', engine: chromium, width: 390, height: 844 },
  { name: 'chromium-dar', engine: chromium, width: 320, height: 740 },
  { name: 'chromium-masaustu', engine: chromium, width: 1280, height: 900 },
  { name: 'webkit-telefon', engine: webkit, width: 390, height: 844 },
];

for (const item of cases) {
  const browser = await item.engine.launch();
  let page;
  try {
    const context = await browser.newContext({
      viewport: { width: item.width, height: item.height },
      hasTouch: true,
      locale: 'tr-TR',
    });
    const external = [], errors = [], failed = [];
    await context.route('**/*', async route => {
      const url = route.request().url();
      if (new URL(url).origin !== origin) {
        external.push(url);
        return route.abort();
      }
      return route.continue();
    });
    page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('pageerror', error => errors.push(error.stack));
    page.on('console', message => {
      if (message.type() === 'error') errors.push(message.text());
    });
    page.on('response', response => {
      if (response.status() >= 400) failed.push(`${response.status()} ${response.url()}`);
    });
    async function open() {
      const response = await page.goto(origin);
      assert.equal(response.status(), 200);
      assert.match(response.headers()['content-security-policy'], /frame-ancestors 'none'/);
      await page.locator('#acilis').waitFor({ state: 'detached' });
      await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
      await page.getByRole('button', { name: 'Denemeyi aç', exact: true }).click();
      await page.getByRole('button', { name: /Örnek Kuzey Market/ }).waitFor();
    }
    const button = name => page.getByRole('button', { name, exact: true });
    // Flutter'ın erişilebilirlik alanı, odaklanınca gerçek düzenleyiciye bağlanır.
    async function write(field, value) {
      await field.click();
      // Motor odak değişimini bir sonraki semantics karesinde düzenleyiciye bağlar.
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.insertText(value);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      assert.equal(await field.inputValue(), value, 'Yazı etkin düzenleyiciye ulaşmalı');
    }
    await open();
    assert.equal(await page.getByText(/Başka Kullanıcının/).count(), 0);
    await page.screenshot({ path: `${output}/${item.name}-cariler.png` });
    const search = page.getByRole('textbox', { name: 'Cari adı veya VKN / TC ara' });
    await write(search, 'bulunmayan-deneme');
    await page.keyboard.press('Enter');
    await page.getByText(/Cari bulunamadı/).waitFor();
    await button('Aramayı temizle').click();
    await page.getByRole('button', { name: /Örnek Kuzey Market/ }).click();
    assert.equal(await button('POS’a geçişi dene').isDisabled(), true);
    await page.getByRole('button', { name: /İş kartı, son dört hane 0001/ }).click();
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await page.screenshot({ path: `${output}/${item.name}-kartlar.png` });
    await button('POS’a geçişi dene').click();
    assert.equal(await button('Geçişi dene').isDisabled(), true);
    await page.getByRole('checkbox', { name: 'Cari ve seçili kartı kontrol ettim.' }).click();
    await button('Geçişi dene').click();
    await page.getByText(/Geçiş denemesi tamamlandı/).waitFor();
    await page.screenshot({ path: `${output}/${item.name}-sonuc.png` });
    await button('Kartlara dön').click();
    await button('Ekranı kilitle').click();
    await button('Denemeye devam et').click();
    await page.getByRole('button', { name: /Örnek Kuzey Market/ }).click();
    assert.equal(await button('POS’a geçişi dene').isDisabled(), true);
    await button('Carilere dön').click();
    await button('Yeni cari').click();
    await write(page.getByRole('textbox', { name: 'Cari adı', exact: true }), 'Örnek Tarayıcı Carisi');
    assert.equal(await page.getByRole('textbox', { name: 'Cari kodu', exact: true }).count(),0);
    await write(page.getByRole('textbox', { name: 'Vergi / TC kimlik numarası', exact: true }), '0000000001');
    await button('Cariyi kaydet').click();
    await page.locator('flt-semantics-host').getByText('Bu vergi / TC numarası zaten kayıtlı. Mevcut cariyi aç.').waitFor();
    await write(page.getByRole('textbox', { name: 'Vergi / TC kimlik numarası', exact: true }), '0000000100');
    await button('Cariyi kaydet').click();
    await page.getByRole('heading', { name: 'Cari profili', exact: true }).waitFor();
    await button('Carilere dön').click();
    await write(search, '0000000100');
    await page.keyboard.press('Enter');
    await page.getByRole('button', { name: /Örnek Tarayıcı Carisi/ }).waitFor();
    await open();
    await write(search, '0000000100');
    await page.keyboard.press('Enter');
    await page.getByText(/Cari bulunamadı/).waitFor();
    assert.deepEqual(external, [], 'Harici ağ isteği olmamalı');
    assert.deepEqual(failed, [], 'Yerel varlıklar eksiksiz yüklenmeli');
    assert.deepEqual(errors, [], 'Tarayıcı hatasız çalışmalı');
    console.log(`PASS ${item.name}: arama, seçim/onay, kilit, cari kaydı, yenileme, ağ sınırı`);
  } catch (error) {
    if (page) {
      console.error(await page.locator('body').ariaSnapshot());
      await page.screenshot({ path: `${output}/${item.name}-hata.png` });
    }
    throw error;
  } finally {
    await browser.close();
  }
}
console.log(`Ekran görüntüleri: ${output}`);
