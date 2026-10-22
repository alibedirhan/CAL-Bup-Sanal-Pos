import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, webkit } from 'playwright';
import { fixture, parola } from '../sunucu-test/fixture.mjs';

// Tahsilat kaydı ve gün sonu uçtan uca (0.9.0): emülatör paketi (4197) + yerel emülatörler +
// taklit DenizPay sonuç ekranları (4199). Gerçek DenizPay'e istek çıkmaz.
const UYGULAMA = 'http://127.0.0.1:4197', POS = 'http://127.0.0.1:4199';
const kok = fileURLToPath(new URL('../../', import.meta.url));
const cikti = await mkdtemp(join(tmpdir(), 'bup-tahsilat-'));
execFileSync('python3', [join(kok, 'tools/yer_imi/uret.py'), '--uygulama', UYGULAMA, '--pos', POS, '--cikti', cikti]);
const kod = decodeURIComponent((await readFile(join(cikti, 'yer_imi_doldur.txt'), 'utf8')).slice('javascript:'.length));
const KIMLIK = '0000000007', CARI = 'Örnek Tahsilat Market';
const sayfa = (govde, baslik) => `<!doctype html><meta charset="utf-8"><title>${baslik}</title><body>${govde}</body>`;
const sonucSayfasi = (baslik, satirlar) => sayfa(`<div class="card"><div class="card-header">${baslik}</div>${satirlar.map(([e, d]) =>
  `<label>${e}</label><input class="form-control" readonly value="${d}">`).join('')}<a>Anasayfaya Dön</a></div>`, 'Sonuç');
const ONAY_NO = 'VP10000000000000001', HATA_NO = 'VP1000000000000002';
const sunucu = createServer((istek, cevap) => {
  const yol = new URL(istek.url, 'http://x').pathname;
  const govde = { '/onay.aspx': sonucSayfasi('Onay Formu', [['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi'],
    ['Üye Sipariş Numarası', '600001'], ['Pos Sipariş Numarası', ONAY_NO], ['Tutar', '4500']]),
  '/hata.aspx': sonucSayfasi('Hata Formu', [['Açıklama', '3D Şifresi Yanlış.'], ['Pos Sipariş Numarası', HATA_NO],
    ['Tutar', '45678,90']]) }[yol];
  if (!govde) { cevap.writeHead(404); cevap.end(); return; }
  cevap.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  cevap.end(govde);
}).listen(4199, '127.0.0.1');
await mkdir('/tmp/bup-pos-tahsilat', { recursive: true });

try {
  for (const [ad, motor] of [['chromium', chromium], ['webkit', webkit]].filter(([n]) => !process.env.TARAYICI || process.env.TARAYICI === n)) {
    const { db } = await fixture();
    await db.collection('cariler').doc('cari-t').set({ sahipId: 'satici-a', ad: CARI, kod: KIMLIK, kodAnahtari: KIMLIK,
      yildizli: false, surum: 1, kartlar: [], sonKart: null, kimlikNo: KIMLIK, silindi: false,
      olusturma: new Date(), guncelleme: new Date() });
    await db.collection('cariKodlari').doc(`satici-a_${KIMLIK}`).set({ sahipId: 'satici-a', kod: KIMLIK, cariId: 'cari-t' });
    const tarayici = await motor.launch();
    let page;
    try {
      const baglam = await tarayici.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, acceptDownloads: true });
      const harici = [];
      await baglam.route('**/*', route => {
        const u = new URL(route.request().url());
        if (u.hostname === 'denizpay.bupilic.com.tr') return route.fulfill({ status: 200, contentType: 'text/html', body: '<p>yapay</p>' });
        if (!['127.0.0.1', 'www.gstatic.com', 'apis.google.com'].includes(u.hostname)) { harici.push(u.href); return route.abort(); }
        return route.continue();
      });
      // Emülatör uyarı şeridi alt çubuktaki düğmelerin üstüne biniyor.
      await baglam.addInitScript(() => addEventListener('DOMContentLoaded', () => {
        const st = document.createElement('style');
        st.textContent = '.firebase-emulator-warning{display:none!important}';
        document.head.append(st);
      }));
      const hatalar = [];
      baglam.on('page', p => p.on('pageerror', e => hatalar.push(`${p.url()} ${e}`)));
      page = await baglam.newPage();
      page.setDefaultTimeout(20000);
      const dugme = name => page.getByRole('button', { name, exact: true });
      const kare = () => page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
      async function yaz(name, value) {
        const f = page.getByRole('textbox', { name, exact: true }); await f.click(); await kare();
        await page.keyboard.press('ControlOrMeta+A'); await page.keyboard.insertText(value); await kare();
      }
      await page.goto(UYGULAMA); await page.locator('#acilis').waitFor({ state: 'detached' });
      const s = page.locator('flt-semantics-placeholder'); if (await s.count()) await s.evaluate(e => e.click());
      await yaz('E-posta', 'satici-a@example.test'); await yaz('Şifre', parola); await dugme('Giriş yap').click();
      await page.getByRole('button', { name: new RegExp(CARI) }).click();
      await dugme('Ödeme sitesine geç').click();
      await page.getByRole('checkbox', { name: 'Cari ve seçili kartı kontrol ettim.' }).click();
      await dugme('Seçimi kontrol et').click();
      const [denizpay] = await Promise.all([baglam.waitForEvent('page'), dugme('DenizPay’e giriş yap').click()]);
      await page.getByText(/sonuç bu cariye kaydedilir/).waitFor();
      await denizpay.close();

      // Son giriş işareti: cari ve kartın son dört hanesi; sır yok.
      const acik = JSON.parse(await page.evaluate(() => localStorage.getItem('bup-acik-giris')));
      assert.equal(acik.cariId, 'cari-t'); assert.equal(acik.cariAd, CARI); assert.equal(acik.kimlikNo, KIMLIK);
      assert.equal(acik.uid, 'satici-a'); assert.match(acik.girisId, /^[A-Za-z0-9]{20}$/);
      let giris;
      for (let i = 0; i < 40 && !(giris = await db.collection('posGirisleri').doc(acik.girisId).get()).exists; i++) await new Promise(r => setTimeout(r, 250));
      assert.equal(giris.data().cariId, 'cari-t'); assert.equal(giris.data().kullaniciAd, 'Örnek satici-a');

      // DenizPay sonuç ekranında yer imi → sonuç sayfası → "Bu cariye kaydet".
      const pos = await baglam.newPage();
      const sonuc = async (yol, bekle) => {
        await pos.goto(`${POS}${yol}`);
        const [s] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
        s.setDefaultTimeout(20000);
        await s.locator('#cari', { hasText: CARI }).waitFor();
        if (bekle) {
          await s.locator('#kaydet:not([hidden]), #durum.hata').first().waitFor();
          if (await s.locator('#durum.hata').count()) throw new Error(`Sonuç sayfası: ${await s.locator('#durum').textContent()}`);
          await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
        }
        return s;
      };
      let s1 = await sonuc('/onay.aspx', true);
      await s1.getByText(/Kaydedildi: /).waitFor();
      await s1.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-kaydedildi.png` });
      await pos.getByText(/BUP Doldur: Kaydedildi: Örnek Tahsilat Market · 4\.500,00 TL/).waitFor();
      const onay = (await db.collection('posIslemleri').doc(ONAY_NO).get()).data();
      assert.deepEqual({ ...onay, zaman: undefined }, { kullaniciId: 'satici-a', kullaniciAd: 'Örnek satici-a', cariId: 'cari-t',
        cariAd: CARI, kimlikNo: KIMLIK, kartSonDort: '', girisId: acik.girisId, sonuc: 'basarili',
        aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: ONAY_NO, uyeSiparisNo: '600001', tutarMetni: '4500',
        tutarKurus: 450000, kaynak: 'yer_imi', zaman: undefined });
      await s1.waitForEvent('close', { timeout: 8000 });
      // Aynı ekrana yeniden dokunmak ikinci kayıt oluşturmaz.
      s1 = await sonuc('/onay.aspx', true);
      await s1.getByText(/zaten kayıtlı/).waitFor();
      await s1.close();
      assert.equal((await db.collection('posIslemleri').get()).size, 1);

      // Sanal POS sekmesi kapalıyken: sonuç telefonda bekler, yeniden girişte yazılır.
      await page.close();
      s1 = await sonuc('/hata.aspx', true);
      await s1.getByText(/Sonuç alındı: Örnek Tahsilat Market · 45\.678,90 TL/).waitFor();
      await new Promise(r => setTimeout(r, 1500));
      assert.equal((await db.collection('posIslemleri').doc(HATA_NO).get()).exists, false);
      page = await baglam.newPage(); page.setDefaultTimeout(20000);
      await page.goto(UYGULAMA); await page.locator('#acilis').waitFor({ state: 'detached' });
      const s2 = page.locator('flt-semantics-placeholder'); if (await s2.count()) await s2.evaluate(e => e.click());
      await yaz('E-posta', 'satici-a@example.test'); await yaz('Şifre', parola); await dugme('Giriş yap').click();
      await page.getByText(/Kaydedildi: Örnek Tahsilat Market · 45\.678,90 TL · başarısız/).waitFor();
      await s1.getByText(/Kaydedildi: /).waitFor(); // açık kalan sonuç sayfası da yanıtı alır
      assert.equal((await db.collection('posIslemleri').doc(HATA_NO).get()).data().sonuc, 'hata');
      assert.equal((await db.collection('posIslemleri').get()).size, 2);
      assert.equal(await page.evaluate(() => localStorage.getItem('bup-sonuc-kutusu')), '[]');

      // Gün sonu: cari, toplam, başarısız deneme; Excel dosyası.
      await page.getByRole('tab', { name: 'Gün sonu', exact: true }).click();
      // Toplam kutusu ekran okuyucuya tek cümle olarak okunur.
      await page.getByText(/Gün toplamı 4\.500,00 TL, 1 başarılı, 1 başarısız işlem/).waitFor();
      await page.getByRole('group', { name: `${CARI} VKN / TC ${KIMLIK} 4.500,00 TL`, exact: true }).waitFor();
      await page.getByText(/3D Şifresi Yanlış\./).waitFor();
      await page.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-gun-sonu.png`, fullPage: true });
      const [indirme] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Excel’e aktar (CSV)' }).click()]);
      assert.match(indirme.suggestedFilename(), /^gun-sonu-\d{4}-\d{2}-\d{2}\.csv$/);
      const csv = await readFile(await indirme.path(), 'utf8');
      assert.ok(csv.startsWith('﻿"Tarih";"Saat";"Cari"'));
      assert.match(csv, new RegExp(`"${CARI}";"${KIMLIK}";"Başarılı";"4500,00";"4500";"${ONAY_NO}";"600001"`));
      assert.match(csv, /"Başarısız";"45678,90";"45678,90";"VP1000000000000002"/);

      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await baglam.close();
      console.log(`PASS ${ad}: giriş kaydı, son giriş işareti, sonuç ekranından kayıt, çift kayıt reddi, kapalı sekmede bekleyen sonuç, gün sonu, Excel dosyası`);
    } catch (e) {
      if (page) {
        await page.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-hata.png` }).catch(() => {});
        console.error(await page.locator('body').ariaSnapshot().catch(() => ''));
      }
      throw e;
    } finally { await tarayici.close(); }
  }
} finally { sunucu.close(); }
