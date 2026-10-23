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
const ONAY_NO = 'VP10000000000000001', HATA_NO = 'VP1000000000000002', ESKI_NO = 'VP10000000000000090';
// 0.10.1 senaryoları: aynı numarada başarısız + başarılı, görünmez işaretler, bağlantı kesilmesi, iki sekme.
const AYNI_NO = 'VP10000000000000095', GORUNMEZ_NO = 'VP10000000000000096', KESIK_NO = 'VP10000000000000097', IKI_NO = 'VP10000000000000098';
const onayS = (no, tutar) => sonucSayfasi('Onay Formu', [['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi'],
  ['Üye Sipariş Numarası', '600009'], ['Pos Sipariş Numarası', no], ['Tutar', tutar]]);
const sunucu = createServer((istek, cevap) => {
  const yol = new URL(istek.url, 'http://x').pathname;
  const govde = { '/onay.aspx': sonucSayfasi('Onay Formu', [['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi'],
    ['Üye Sipariş Numarası', '600001'], ['Pos Sipariş Numarası', ONAY_NO], ['Tutar', '4500']]),
  '/hata.aspx': sonucSayfasi('Hata Formu', [['Açıklama', '3D Şifresi Yanlış.'], ['Pos Sipariş Numarası', HATA_NO],
    ['Tutar', '45678,90']]),
  '/ayni-hata.aspx': sonucSayfasi('Hata Formu', [['Açıklama', 'İşlem onaylanmadı.'], ['Pos Sipariş Numarası', AYNI_NO], ['Tutar', '300']]),
  '/ayni-onay.aspx': onayS(AYNI_NO, '300'),
  '/gorunmez.aspx': sonucSayfasi('Onay Formu', [['Açıklama', '&lrm;Ödeme Başarıyla Gerçekleştirildi&rlm;'],
    ['Üye Sipariş Numarası', '600&#8203;096'], ['Pos Sipariş Numarası', `VP&#8203;${GORUNMEZ_NO.slice(2)}&lrm;`], ['Tutar', '4.500,00&#8288;']]),
  '/kesik.aspx': onayS(KESIK_NO, '1000'), '/iki.aspx': onayS(IKI_NO, '2000') }[yol];
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
      async function girisYap() {
        await page.goto(UYGULAMA); await page.locator('#acilis').waitFor({ state: 'detached' });
        const s = page.locator('flt-semantics-placeholder'); if (await s.count()) await s.evaluate(e => e.click());
        await yaz('E-posta', 'satici-a@example.test'); await yaz('Şifre', parola); await dugme('Giriş yap').click();
      }
      await girisYap();
      await page.getByRole('button', { name: new RegExp(CARI) }).click();
      await dugme('Ödeme sitesine geç').click();
      await page.getByRole('checkbox', { name: 'Cari ve seçili kartı kontrol ettim.' }).click();
      await dugme('Seçimi kontrol et').click();
      const [denizpay] = await Promise.all([baglam.waitForEvent('page'), dugme('DenizPay’e giriş yap').click()]);
      await page.getByText(/sonuç bu cariye kaydedilir/).waitFor();
      await denizpay.close();

      // Telefondaki giriş listesi: cari ve kartın son dört hanesi; sır yok.
      const girisler = JSON.parse(await page.evaluate(() => localStorage.getItem('bup-acik-giris')));
      assert.equal(girisler.length, 1);
      const [acik] = girisler;
      assert.equal(acik.v, 2); assert.equal(acik.son - acik.an, 2 * 60 * 60 * 1000);
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
      assert.ok(Math.abs(onay.okunma.toMillis() - Date.now()) < 120000, 'okunma telefon saatiyle yazılır');
      assert.deepEqual({ ...onay, zaman: undefined, okunma: undefined }, { kullaniciId: 'satici-a', kullaniciAd: 'Örnek satici-a', cariId: 'cari-t',
        cariAd: CARI, kimlikNo: KIMLIK, kartSonDort: '', girisId: acik.girisId, sonuc: 'basarili',
        aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: ONAY_NO, uyeSiparisNo: '600001', tutarMetni: '4500',
        tutarKurus: 450000, kaynak: 'yer_imi', eslesme: 'tek_giris', okunma: undefined, zaman: undefined });
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
      assert.equal((await db.collection('posIslemleri').doc(`${HATA_NO}-h`).get()).exists, false);
      // 0.9.0 sonuç sayfasından telefonda kalmış (1. biçim, eşleşmesiz) sonuç da gerçek kurallarla yazılır.
      await s1.evaluate(({ acik, ESKI_NO }) => {
        const l = JSON.parse(localStorage.getItem('bup-sonuc-kutusu') ?? '[]');
        l.push({ v: 1, uid: acik.uid, girisId: acik.girisId, cariId: acik.cariId, cariAd: acik.cariAd, kimlikNo: acik.kimlikNo,
          kartSonDort: '', sonuc: 'basarili', aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: ESKI_NO,
          uyeSiparisNo: '', tutarMetni: '250', okunma: Date.now() });
        localStorage.setItem('bup-sonuc-kutusu', JSON.stringify(l));
      }, { acik, ESKI_NO });
      page = await baglam.newPage(); page.setDefaultTimeout(20000);
      await girisYap();
      await page.getByText(/2 DenizPay sonucu kaydedildi\. Son: Kaydedildi: Örnek Tahsilat Market · 250,00 TL/).waitFor();
      await s1.getByText(/Kaydedildi: /).waitFor(); // açık kalan sonuç sayfası da yanıtı alır
      assert.equal((await db.collection('posIslemleri').doc(`${HATA_NO}-h`).get()).data().sonuc, 'hata');
      let eski;
      for (let i = 0; i < 40 && !(eski = await db.collection('posIslemleri').doc(ESKI_NO).get()).exists; i++) await new Promise(r => setTimeout(r, 250));
      assert.deepEqual([eski.data().eslesme, eski.data().cariId], ['son_giris', 'cari-t']);
      assert.equal((await db.collection('posIslemleri').get()).size, 3);
      assert.equal(await page.evaluate(() => localStorage.getItem('bup-sonuc-kutusu')), '[]');
      // Yeni açılan Sanal POS sekmesi telefondaki DenizPay girişini silmez (0.10.0'da siliyordu:
      // süren ödemenin sonucu cariye bağlanamıyordu).
      assert.deepEqual(JSON.parse(await page.evaluate(() => localStorage.getItem('bup-acik-giris'))).map(g => g.girisId), [acik.girisId]);

      // Gün sonu: cari, toplam, başarısız deneme; Excel dosyası.
      await page.getByRole('tab', { name: 'Gün sonu', exact: true }).click();
      // Toplam kutusu ekran okuyucuya tek cümle olarak okunur.
      await page.getByText(/Gün toplamı 4\.750,00 TL, 2 başarılı, 1 başarısız işlem/).waitFor();
      await page.getByRole('group', { name: `${CARI} VKN / TC ${KIMLIK} 4.750,00 TL`, exact: true }).waitFor();
      await page.getByText(/3D Şifresi Yanlış\./).waitFor();
      await page.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-gun-sonu.png`, fullPage: true });
      const [indirme] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Excel’e aktar (CSV)' }).click()]);
      assert.match(indirme.suggestedFilename(), /^gun-sonu-\d{4}-\d{2}-\d{2}\.csv$/);
      const csv = await readFile(await indirme.path(), 'utf8');
      assert.ok(csv.startsWith('﻿"Tarih";"Saat";"Cari"'));
      assert.match(csv, new RegExp(`"${CARI}";"${KIMLIK}";"Başarılı";"4500,00";"4500";"${ONAY_NO}";"600001"`));
      assert.match(csv, /"Başarısız";"45678,90";"45678,90";"VP1000000000000002"/);
      assert.match(csv, /"Telefondaki son DenizPay girişiyle";/);
      assert.match(csv, /"Telefondaki tek DenizPay girişiyle";"\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}"/);

      const belge = async (no, n = 40) => {
        let d;
        for (let i = 0; i < n && !(d = await db.collection('posIslemleri').doc(no).get()).exists; i++) await new Promise(r => setTimeout(r, 250));
        return d.exists ? d.data() : null;
      };
      // Sonuç sayfası "Kaydedildi" yanıtını alınca kendiliğinden kapanır; kapanmadan önce yazı okunur.
      const kaydedildi = async (s, desen) => { await s.getByText(desen).waitFor(); await s.waitForEvent('close', { timeout: 8000 }); };

      // 1) Başarısız deneme, ardından DenizPay aynı numarayla başarılı ödeme: ikisi ayrı yazılır,
      // başarılı ödeme "zaten kayıtlı" diye yutulmaz.
      await kaydedildi(await sonuc('/ayni-hata.aspx', true), /Kaydedildi: Örnek Tahsilat Market · 300,00 TL · başarısız/);
      await kaydedildi(await sonuc('/ayni-onay.aspx', true), /Kaydedildi: Örnek Tahsilat Market · 300,00 TL · başarılı/);
      assert.deepEqual([(await belge(`${AYNI_NO}-h`)).sonuc, (await belge(AYNI_NO)).sonuc], ['hata', 'basarili']);
      assert.equal((await belge(AYNI_NO)).posSiparisNo, AYNI_NO);

      // 2) Ekranda görünmeyen işaretler: okunur, temiz yazılır, telefonda kaybolmaz.
      await kaydedildi(await sonuc('/gorunmez.aspx', true), /Kaydedildi: Örnek Tahsilat Market · 4\.500,00 TL · başarılı/);
      const gor = await belge(GORUNMEZ_NO);
      assert.deepEqual([gor.aciklama, gor.uyeSiparisNo, gor.tutarMetni, gor.tutarKurus], ['Ödeme Başarıyla Gerçekleştirildi', '600096', '4.500,00', 450000]);

      // 3) İnternet kesik: sonuç telefona alınır; Sanal POS sunucuya ulaşamaz, sonuç silinmez.
      // Bağlantı gelince Sanal POS kendiliğinden toparlanır ve yazar (sayfa yenilenmeden).
      const kesik = await sonuc('/kesik.aspx', false);
      await kesik.locator('#kaydet:not([hidden])').waitFor();
      await baglam.setOffline(true);
      await kesik.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await kesik.getByText(/Sonuç alındı: Örnek Tahsilat Market · 1\.000,00 TL/).waitFor();
      await new Promise(r => setTimeout(r, 5000));
      assert.equal(await belge(KESIK_NO, 1), null);
      assert.deepEqual(JSON.parse(await page.evaluate(() => localStorage.getItem('bup-sonuc-kutusu'))).map(k => k.posSiparisNo), [KESIK_NO]);
      await baglam.setOffline(false);
      await page.getByText(/Kaydedildi: Örnek Tahsilat Market · 1\.000,00 TL · başarılı/).waitFor({ timeout: 60000 });
      await kesik.getByText(/Kaydedildi: /).waitFor(); // açık kalan sonuç sayfası da öğrenir
      assert.equal((await belge(KESIK_NO)).tutarKurus, 100000);
      assert.equal(await page.evaluate(() => localStorage.getItem('bup-sonuc-kutusu')), '[]');

      // 4) İki Sanal POS sekmesi açık: ikisi aynı sonucu aynı anda yazmaya çalışır. Tek kayıt
      // oluşur, hiçbir sekme yanlış "Kaydedilemedi" demez.
      const page2 = await baglam.newPage(); page2.setDefaultTimeout(20000);
      { const p0 = page; page = page2; await girisYap(); page = p0; }
      await page2.getByRole('tab', { name: 'Gün sonu', exact: true }).waitFor();
      const iki = await sonuc('/iki.aspx', true);
      await iki.getByText(/Kaydedildi: |zaten kayıtlı/).first().waitFor();
      assert.equal((await belge(IKI_NO)).tutarKurus, 200000);
      await new Promise(r => setTimeout(r, 3000));
      for (const p of [page, page2]) assert.equal(await p.getByText(/Kaydedilemedi|okunamadı|bekliyor/).count(), 0);
      assert.equal(await page.evaluate(() => localStorage.getItem('bup-sonuc-kutusu')), '[]');
      await page2.close();

      // Gün sonu: aynı numaralı başarısız deneme toplama girmez, başarılısı girer.
      // Başarılı: 4500 + 250 + 300 + 4500 + 1000 + 2000; başarısız: 45678,90 ve 300.
      assert.equal((await db.collection('posIslemleri').get()).size, 8);
      await page.getByRole('tab', { name: 'Gün sonu', exact: true }).click();
      await page.getByText(/Gün toplamı 12\.550,00 TL, 6 başarılı, 2 başarısız işlem/).waitFor();
      await page.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-gun-sonu-2.png`, fullPage: true });

      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await baglam.close();
      console.log(`PASS ${ad}: giriş kaydı, son giriş işareti, sonuç ekranından kayıt, çift kayıt reddi, kapalı sekmede bekleyen sonuç, gün sonu, Excel dosyası, 0.9.0’dan bekleyen sonuç, aynı numarada başarısız+başarılı, görünmez işaretler, bağlantı kesilmesi, iki sekme (gerçek kurallar)`);
    } catch (e) {
      if (page) {
        await page.screenshot({ path: `/tmp/bup-pos-tahsilat/${ad}-hata.png` }).catch(() => {});
        console.error(await page.locator('body').ariaSnapshot().catch(() => ''));
      }
      throw e;
    } finally { await tarayici.close(); }
  }
} finally { sunucu.close(); }
