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
const KART = '4111111111111111', SAHIBI = 'ÖRNEK KART SAHİBİ', KIMLIK = '0000000001', KIMLIK2 = '0000000002';
// Sonuç okuma ve cari eşleştirmenin tarayıcısız birim testleri: sonuc-saf.mjs.

const sayfa = (govde, baslik) => `<!doctype html><meta charset="utf-8"><title>${baslik}</title><body>${govde}</body>`;
// card.js benzeri: numara kutusu her girişte dörtlü gruplanır; gönderim kaydedilir.
const kartSayfasi = firma => sayfa(`<p>Firma İsmi : ÖRNEK YAPAY FİRMA (<a href="#">${firma}</a>)</p>
<form id="f" onsubmit="window.gonderildi=true;return false"><input name="name" id="name" placeholder="Full Name">
<input name="number" id="number" placeholder="•••• •••• •••• ••••"><input name="expiry" id="expiry" placeholder="MM/YY">
<input name="cvc" id="cvc" placeholder="CVC"><input name="Tutar" id="Tutar"><input type="submit" name="Button1" value="Öde"></form>
<script>document.getElementById('number').addEventListener('input',e=>{const d=e.target.value.replace(/\\D/g,'');e.target.value=d.replace(/(.{4})(?=.)/g,'$1 ');});
document.querySelector('[name=Button1]').addEventListener('click',()=>{window.tiklandi=true;});</script>`, 'Ödeme');
// DenizPay sonuç ekranları (kullanıcının 22 Ekim görüntüleri; Bootstrap benzeri, değerler yapay).
const sonucSayfasi = (baslik, satirlar, firma = '') => sayfa(`<nav>Bupiliç <button>☰</button></nav>${firma}
<div class="card"><div class="card-header">${baslik}</div><div class="card-body">${satirlar.map(([e, d]) =>
  `<div class="form-group"><label>${e}</label><div class="input-group"><input class="form-control" readonly value="${d}">${e === 'Tutar' ? '<span>TL</span>' : ''}</div></div>`).join('')}
</div><a class="btn">Anasayfaya Dön</a></div>`, 'Sonuç');
const ONAY = [['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi'], ['Üye Sipariş Numarası', '600001'], ['Pos Sipariş Numarası', 'VP10000000000000001'], ['Tutar', '4500']];
const HATA = [['Açıklama', '3D Şifresi Yanlış.'], ['Pos Sipariş Numarası', 'VP1000000000000002'], ['Tutar', '45678,90']];
const onay = no => [ONAY[0], ['Üye Sipariş Numarası', '600009'], ['Pos Sipariş Numarası', no], ['Tutar', '100']];
// Görülmemiş düzen: tablo hücreleri (innerText'te sekmeyle ayrılır) ve CSS ile büyük harf.
// Banka sayfalarında rastlanan görünmez işaretler (yön, sıfır genişlik, kelime birleştirici).
const gorunmezSayfasi = sonucSayfasi('Onay Formu', [['Açıklama', '&lrm;Ödeme Başarıyla Gerçekleştirildi&rlm;'],
  ['Üye Sipariş Numarası', '600&#8203;061'], ['Pos Sipariş Numarası', 'VP&#8203;10000000000000060&lrm;'], ['Tutar', '4.500,00&#8288;']]);
// Başarısız denemeden sonra aynı numarayla başarılı ödeme (DenizPay numarayı yeniden kullanırsa).
const AYNI = 'VP10000000000000080';
const tabloSayfasi = sayfa(`<h2 style="text-transform:uppercase">Onay Formu</h2><table style="text-transform:uppercase">
<tr><td>Açıklama</td><td>Ödeme Başarıyla Gerçekleştirildi</td></tr><tr><td>Pos Sipariş Numarası</td><td>VP10000000000000070</td></tr>
<tr><td>Tutar</td><td>2.500,00 TL</td></tr></table>`, 'Sonuç');
const statik = ad => readFileSync(join(kok, 'web', ad));
const sunucular = [
  [4191, yol => ({ '/doldur.html': ['text/html', statik('doldur.html')], '/kurulum.html': ['text/html', statik('kurulum.html')],
    '/doldurma.js': ['text/javascript', statik('doldurma.js')], '/kart_kasasi.js': ['text/javascript', statik('kart_kasasi.js')],
    '/doldur_sayfasi.js': ['text/javascript', readFileSync(join(cikti, 'doldur_sayfasi.js'))],
    '/kurulum.js': ['text/javascript', readFileSync(join(cikti, 'kurulum.js'))], '/bos': ['text/html', sayfa('', 'Uygulama')],
    '/sonuc.html': ['text/html', statik('sonuc.html')], '/sonuc_coz.js': ['text/javascript', statik('sonuc_coz.js')],
    '/cari_eslestir.js': ['text/javascript', statik('cari_eslestir.js')],
    '/acik_giris.js': ['text/javascript', statik('acik_giris.js')], '/sonuc_kutusu.js': ['text/javascript', statik('sonuc_kutusu.js')],
    '/sonuc_sayfasi.js': ['text/javascript', readFileSync(join(cikti, 'sonuc_sayfasi.js'))] })[yol]],
  [4199, yol => ({ '/index.aspx': ['text/html', kartSayfasi(KIMLIK)], '/baska.aspx': ['text/html', kartSayfasi('0000000009')],
    '/onay.aspx': ['text/html', sonucSayfasi('Onay Formu', ONAY)], '/hata.aspx': ['text/html', sonucSayfasi('Hata Formu', HATA)],
    '/baska-onay.aspx': ['text/html', sonucSayfasi('Onay Formu', ONAY, '<p>Firma İsmi : BAŞKA YAPAY FİRMA (<a>0000000009</a>)</p>')],
    '/onay2.aspx': ['text/html', sonucSayfasi('Onay Formu', onay('VP10000000000000020'))],
    '/onay3.aspx': ['text/html', sonucSayfasi('Onay Formu', onay('VP10000000000000030'))],
    '/onay4.aspx': ['text/html', sonucSayfasi('Onay Formu', onay('VP10000000000000040'))],
    '/firma-onay.aspx': ['text/html', sonucSayfasi('Onay Formu', onay('VP10000000000000050'), `<p>Firma İsmi : İKİNCİ YAPAY FİRMA (<a>${KIMLIK2}</a>)</p>`)],
    '/tablo.aspx': ['text/html', tabloSayfasi], '/gorunmez.aspx': ['text/html', gorunmezSayfasi],
    '/ayni-hata.aspx': ['text/html', sonucSayfasi('Hata Formu', [['Açıklama', 'İşlem onaylanmadı.'], ['Pos Sipariş Numarası', AYNI], ['Tutar', '100']])],
    '/ayni-onay.aspx': ['text/html', sonucSayfasi('Onay Formu', onay(AYNI))],
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

      // Yer imi sürümü: telefondaki numarasız ilk sürüm çalışır; eski numara yeniden kurulum ister.
      const sayfaYaniti = async ek => {
        const [p] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(([u, ek]) => {
          window.gelenPaket = null;
          addEventListener('message', e => { if (e.data?.tur === 'bup-doldur-paket') window.gelenPaket = e.data; }, { once: true });
          window.open(`${u}/doldur.html#b=${'c'.repeat(24)}${ek}`);
        }, [UYGULAMA, ek])]);
        await pos.waitForFunction(() => window.gelenPaket, null, { timeout: 8000 });
        await p.close().catch(() => {});
        return pos.evaluate(() => window.gelenPaket);
      };
      assert.equal((await sayfaYaniti('')).kart?.numara, KART);
      assert.equal((await sayfaYaniti('&s=1')).kart?.numara, KART);
      const eski = await sayfaYaniti('&s=0');
      assert.equal(eski.kart, undefined);
      assert.match(eski.hata, /Yer imin eski/);

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

      // Sonuç ekranı (yer imi 3): sonuç bu telefondaki girişlerden DenizPay sekmesine ait olana
      // bağlanır, onayla telefondaki kutuya bırakılır. Yeni sekme: önceki adımların kart notu yok.
      const acikKur = (cariId = 'cari-1', cariAd = 'Örnek Yapay Market', kimlikNo = KIMLIK) => uygulama.evaluate(async g => {
        await import('./acik_giris.js');
        const an = Date.now();
        return bupAcikGiris.ekle(JSON.stringify({ v: 2, uid: 'uid-1', girisId: (g.cariId.replace(/-/g, '') + 'A'.repeat(20)).slice(0, 20),
          cariId: g.cariId, cariAd: g.cariAd, kimlikNo: g.kimlikNo, kartSonDort: '1111', an, son: an + 7200000 }));
      }, { cariId, cariAd, kimlikNo });
      await pos.close();
      const sekme = await baglam.newPage();
      const sonucAc = async yol => {
        await sekme.goto(`${POS}${yol}`);
        const [s] = await Promise.all([baglam.waitForEvent('page'), sekme.evaluate(kod)]);
        await s.waitForLoadState();
        return s;
      };
      const kutu = () => uygulama.evaluate(() => JSON.parse(localStorage.getItem('bup-sonuc-kutusu') ?? '[]'));
      const kayit = async no => (await kutu()).find(k => k.posSiparisNo === no);
      await acikKur();
      let s = await sonucAc('/onay.aspx');
      await s.locator('#sonuc', { hasText: '✓ Ödeme başarılı' }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#cari').textContent(), `Örnek Yapay Market · ${KIMLIK}`);
      assert.equal(await s.locator('#tutar').textContent(), '4.500,00 TL');
      assert.equal(await s.locator('#pos-no').textContent(), 'VP10000000000000001');
      assert.match(await s.locator('#eslesme').textContent(), /yalnız bu cariyle/);
      assert.equal(await s.locator('#secim').isHidden(), true);
      assert.ok(!(s.url().includes('#')), 'İstek kimliği adres çubuğunda kalmamalı');
      await s.screenshot({ path: `/tmp/bup-pos-sonuc-${ad}.png` });
      // Kişi onaylamadan telefona bırakılmaz; onaylayınca kutuya bir kez girer.
      assert.deepEqual(await kutu(), []);
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 4\.500,00 TL/).waitFor();
      await sekme.getByText(/kayıt kendiliğinden yapılır/).waitFor();
      const [b1] = await kutu();
      assert.deepEqual({ ...b1, okunma: 0 }, { v: 2, uid: 'uid-1', girisId: 'cari1AAAAAAAAAAAAAAA', cariId: 'cari-1',
        cariAd: 'Örnek Yapay Market', kimlikNo: KIMLIK, kartSonDort: '1111', sonuc: 'basarili',
        aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: 'VP10000000000000001', uyeSiparisNo: '600001',
        tutarMetni: '4500', eslesme: 'tek_giris', okunma: 0 });
      assert.ok(Math.abs(b1.okunma - Date.now()) < 60000);
      // Sanal POS sekmesi yazınca yanıtlar: sonuç sayfası ve DenizPay kutusu gösterir, sayfa kapanır.
      await uygulama.evaluate(() => { import('./sonuc_kutusu.js').then(() => bupSonucKutusu.yanitla(JSON.stringify(
        { kimlik: 'VP10000000000000001', tamam: true, mesaj: 'Kaydedildi: Örnek Yapay Market · 4.500,00 TL', an: 1 }))); });
      await sekme.getByText(/BUP Doldur: Kaydedildi: Örnek Yapay Market/).waitFor({ timeout: 8000 });
      await s.waitForEvent('close', { timeout: 8000 });
      // Aynı ekrana yeniden dokunmak kutuya ikinci kayıt eklemez.
      s = await sonucAc('/onay.aspx');
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/zaten alınmıştı/).waitFor();
      assert.equal((await kutu()).length, 1);
      await s.close();
      s = await sonucAc('/hata.aspx');
      await s.locator('#sonuc', { hasText: '✗ Ödeme başarısız' }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#aciklama').textContent(), '3D Şifresi Yanlış.');
      assert.equal(await s.locator('#tutar').textContent(), '45.678,90 TL');
      await s.close();
      // Tablo düzeni ve büyük harf: yer imi tanır, sonuç okunur.
      s = await sonucAc('/tablo.aspx');
      await s.locator('#pos-no', { hasText: 'VP10000000000000070' }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#tutar').textContent(), '2.500,00 TL');
      await s.close();
      // Görünmez işaretler okunan değerden atılır; telefona temiz sonuç bırakılır.
      s = await sonucAc('/gorunmez.aspx');
      await s.locator('#pos-no', { hasText: 'VP10000000000000060' }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#tutar').textContent(), '4.500,00 TL');
      assert.equal(await s.locator('#aciklama').textContent(), 'Ödeme Başarıyla Gerçekleştirildi');
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 4\.500,00 TL/).waitFor();
      const g = await kayit('VP10000000000000060');
      assert.deepEqual([g.aciklama, g.uyeSiparisNo, g.tutarMetni], ['Ödeme Başarıyla Gerçekleştirildi', '600061', '4.500,00']);
      await s.close();
      // Başarısız deneme ve aynı numarayla gelen başarılı ödeme: ikisi de telefona alınır.
      s = await sonucAc('/ayni-hata.aspx');
      await s.locator('#sonuc', { hasText: '✗ Ödeme başarısız' }).waitFor({ timeout: 8000 });
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 100,00 TL/).waitFor();
      await s.close();
      s = await sonucAc('/ayni-onay.aspx');
      await s.locator('#sonuc', { hasText: '✓ Ödeme başarılı' }).waitFor({ timeout: 8000 });
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 100,00 TL/).waitFor();
      await s.close();
      assert.deepEqual((await kutu()).filter(k => k.posSiparisNo === AYNI).map(k => k.sonuc), ['hata', 'basarili']);

      // İkinci cariyle de girildi, kart notu yok: kişi seçmeden kaydedilmez.
      await acikKur('cari-2', 'İkinci Yapay Bayi', KIMLIK2);
      s = await sonucAc('/onay2.aspx');
      await s.locator('#secim').waitFor({ timeout: 8000 });
      assert.match(await s.locator('#secim-neden').textContent(), /birden fazla cariyle/);
      assert.equal(await s.locator('#cari').textContent(), 'Seçilmedi');
      const secimDugmesi = s.getByRole('button', { name: 'Seçili cariye kaydet' });
      assert.equal(await secimDugmesi.isDisabled(), true);
      const secenekler = s.getByRole('radio');
      assert.equal(await secenekler.count(), 2);
      assert.deepEqual(await secenekler.evaluateAll(l => l.map(e => e.checked)), [false, false]);
      assert.match(await s.locator('#adaylar label').first().textContent(), /İkinci Yapay Bayi.*son giriş/);
      await sekme.getByText(/ödemenin ait olduğu cariyi seç/).waitFor();
      await s.screenshot({ path: `/tmp/bup-pos-sonuc-secim-${ad}.png` });
      await s.getByRole('radio', { name: /Örnek Yapay Market/ }).check();
      assert.equal(await s.locator('#cari').textContent(), `Örnek Yapay Market · ${KIMLIK}`);
      await secimDugmesi.click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 100,00 TL/).waitFor();
      assert.deepEqual([(await kayit('VP10000000000000020')).cariId, (await kayit('VP10000000000000020')).eslesme], ['cari-1', 'secim']);
      await s.close();
      // Sunucuya yazılmamış ilk seçim başka cariyle değiştirilemez.
      s = await sonucAc('/onay2.aspx');
      await s.getByRole('radio', { name: /İkinci Yapay Bayi/ }).check();
      await s.getByRole('button', { name: 'Seçili cariye kaydet' }).click();
      await s.getByText(/daha önce Örnek Yapay Market carisi için alındı ve değiştirilemez/).waitFor();
      assert.equal((await kayit('VP10000000000000020')).cariId, 'cari-1');
      await s.close();

      // Kart sayfasında yer imi bu sekmenin firmasını not eder (kart yazılmasa da): sonuç o cariye kesin bağlanır.
      // Önce bu cariyle yeniden girilir (yeni giriş: son giriş bu cari; ikinci cari daha önce girmişti).
      await new Promise(r => setTimeout(r, 20));
      await acikKur();
      await sekme.goto(`${POS}/index.aspx`);
      const [kartSayfasiAcilan] = await Promise.all([baglam.waitForEvent('page'), sekme.evaluate(kod)]);
      await kartSayfasiAcilan.close().catch(() => {});
      const not = await sekme.evaluate(() => JSON.parse(sessionStorage.getItem('bup-sekme-firma')));
      assert.deepEqual(Object.keys(not).sort(), ['an', 'vkn']);
      assert.equal(not.vkn, KIMLIK);
      s = await sonucAc('/onay3.aspx');
      await s.locator('#eslesme', { hasText: /kart sayfasındaki firma numarasıyla/ }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#cari').textContent(), `Örnek Yapay Market · ${KIMLIK}`);
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı/).waitFor();
      assert.equal((await kayit('VP10000000000000030')).eslesme, 'kart_sayfasi');
      await s.close();
      // Başka sekmenin notu bu sekmeye geçmez.
      const baskaSekme = await baglam.newPage();
      await baskaSekme.goto(`${POS}/onay4.aspx`);
      assert.equal(await baskaSekme.evaluate(() => sessionStorage.getItem('bup-sekme-firma')), null);
      await baskaSekme.close();
      // Kart yazıldıktan sonra başka cariyle girildi: DenizPay oturumu değişmiş olabilir, seçim istenir.
      await new Promise(r => setTimeout(r, 20));
      await acikKur('cari-2', 'İkinci Yapay Bayi', KIMLIK2);
      s = await sonucAc('/onay4.aspx');
      await s.locator('#secim-neden', { hasText: /sekmesi eski olabilir/ }).waitFor({ timeout: 8000 });
      await s.close();
      // Eski sekmeye dönülüp kart sayfasında yer imine yeniden dokunuldu: not yenilenir ama sekme
      // eskidir (sonra başka cariyle girildi). Kesin denmez, seçim istenir.
      await sekme.goto(`${POS}/index.aspx`);
      const [yeniden] = await Promise.all([baglam.waitForEvent('page'), sekme.evaluate(kod)]);
      await yeniden.close().catch(() => {});
      await sekme.getByText(/BUP Doldur/).first().waitFor();
      s = await sonucAc('/onay4.aspx');
      await s.locator('#secim-neden', { hasText: /sekmesi eski olabilir/ }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#cari').textContent(), 'Seçilmedi');
      await s.close();
      // Sonuç ekranında firma numarası varsa o kesindir.
      s = await sonucAc('/firma-onay.aspx');
      await s.locator('#eslesme', { hasText: /sonuç ekranındaki firma numarasıyla/ }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#cari').textContent(), `İkinci Yapay Bayi · ${KIMLIK2}`);
      await s.close();
      // Sayfadaki firma bu telefonda girilen carilerden değil: kaydedilmez, DenizPay sekmesindeki kutu da söyler.
      s = await sonucAc('/baska-onay.aspx');
      await s.getByText(/girilen carilerden değil/).waitFor({ timeout: 8000 });
      await sekme.getByText(/girilen carilerden değil/).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#ozet').isHidden(), true);
      await s.close();
      // Eski yer imi (2. sürüm) sonuç sayfasında yeniden kurulum ister.
      const [eskiSonuc] = await Promise.all([baglam.waitForEvent('page'),
        sekme.evaluate(u => { window.open(`${u}/sonuc.html#b=${'e'.repeat(24)}&s=2`); }, UYGULAMA)]);
      await eskiSonuc.getByText(/Yer imin eski/).waitFor({ timeout: 8000 });
      await eskiSonuc.close();
      // Giriş yoksa (ör. boş giriş sayfası elle açıldı) sonuç bir cariye bağlanmaz.
      await uygulama.evaluate(() => bupAcikGiris.temizle());
      s = await sonucAc('/onay.aspx');
      await s.getByText(/açılmış bir DenizPay girişi yok/).waitFor({ timeout: 8000 });
      await s.close();
      // Başka site sonuç sayfasını açsa bile istek ona gitmez, özet beklenmez.
      await kotu.evaluate(() => { window.gelen = []; addEventListener('message', e => window.gelen.push(e.data)); });
      const [k3] = await Promise.all([baglam.waitForEvent('page'),
        kotu.evaluate(u => { window.open(`${u}/sonuc.html#b=${'d'.repeat(24)}&s=3`); }, UYGULAMA)]);
      await k3.getByText(/yanıt gelmedi/).waitFor({ timeout: 12000 });
      assert.deepEqual(await kotu.evaluate(() => window.gelen.filter(m => m?.tur?.startsWith('bup-sonuc'))), []);
      await k3.close();

      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await baglam.close();
      console.log(`PASS ${ad}: kart yazma, CVV/tutar/düğmeye dokunmama, firma eşleşmesi, köken reddi, süre, sonuç ekranı okuma (kutu/tablo), cari eşleştirme (tek giriş/seçim/kart notu/eski sekme/sonuç ekranı), görünmez işaretler, aynı numarada başarısız+başarılı, ağ yalıtımı`);
    } finally { await tarayici.close(); }
  }
} finally { for (const s of sunucular) s.close(); }
