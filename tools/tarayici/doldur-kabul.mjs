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
const ornekler = JSON.parse(readFileSync(join(kok, 'test/veri/tahsilat_ornekleri.json'), 'utf8'));
const coz = await import(join(kok, 'web/sonuc_coz.js'));
for (const [metin, kurus] of ornekler.tutarlar) assert.equal(coz.tutarCoz(metin), kurus, `tutar "${metin}"`);
for (const o of ornekler.sonuclar) {
  const r = coz.sonucCoz(o.sayfa);
  if (o.beklenen.ok) assert.deepEqual(r, o.beklenen, o.ad); else assert.equal(r.ok, false, o.ad);
}
assert.equal(coz.tutarYaz(4567890), '45.678,90 TL');
console.log(`PASS sonuç okuma: ${ornekler.tutarlar.length} tutar, ${ornekler.sonuclar.length} ekran örneği (Dart ile ortak)`);

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
const statik = ad => readFileSync(join(kok, 'web', ad));
const sunucular = [
  [4191, yol => ({ '/doldur.html': ['text/html', statik('doldur.html')], '/kurulum.html': ['text/html', statik('kurulum.html')],
    '/doldurma.js': ['text/javascript', statik('doldurma.js')], '/kart_kasasi.js': ['text/javascript', statik('kart_kasasi.js')],
    '/doldur_sayfasi.js': ['text/javascript', readFileSync(join(cikti, 'doldur_sayfasi.js'))],
    '/kurulum.js': ['text/javascript', readFileSync(join(cikti, 'kurulum.js'))], '/bos': ['text/html', sayfa('', 'Uygulama')],
    '/sonuc.html': ['text/html', statik('sonuc.html')], '/sonuc_coz.js': ['text/javascript', statik('sonuc_coz.js')],
    '/acik_giris.js': ['text/javascript', statik('acik_giris.js')], '/sonuc_kutusu.js': ['text/javascript', statik('sonuc_kutusu.js')],
    '/sonuc_sayfasi.js': ['text/javascript', readFileSync(join(cikti, 'sonuc_sayfasi.js'))] })[yol]],
  [4199, yol => ({ '/index.aspx': ['text/html', kartSayfasi(KIMLIK)], '/baska.aspx': ['text/html', kartSayfasi('0000000009')],
    '/onay.aspx': ['text/html', sonucSayfasi('Onay Formu', ONAY)], '/hata.aspx': ['text/html', sonucSayfasi('Hata Formu', HATA)],
    '/baska-onay.aspx': ['text/html', sonucSayfasi('Onay Formu', ONAY, '<p>Firma İsmi : BAŞKA YAPAY FİRMA (<a>0000000009</a>)</p>')],
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

      // Sonuç ekranı (yer imi 2): son girişin carisine bağlanır, onayla telefondaki kutuya bırakılır.
      const acikKur = (cariAd = 'Örnek Yapay Market') => uygulama.evaluate(async ({ KIMLIK, cariAd }) => {
        await import('./acik_giris.js');
        return bupAcikGiris.hazirla(JSON.stringify({ v: 1, uid: 'uid-1', girisId: 'A'.repeat(20), cariId: 'cari-1',
          cariAd, kimlikNo: KIMLIK, kartSonDort: '1111', son: Date.now() + 3600000 }));
      }, { KIMLIK, cariAd });
      const sonucAc = async yol => {
        await pos.goto(`${POS}${yol}`);
        const [s] = await Promise.all([baglam.waitForEvent('page'), pos.evaluate(kod)]);
        await s.waitForLoadState();
        return s;
      };
      await acikKur();
      let s = await sonucAc('/onay.aspx');
      await s.locator('#sonuc', { hasText: '✓ Ödeme başarılı' }).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#cari').textContent(), `Örnek Yapay Market · ${KIMLIK}`);
      assert.equal(await s.locator('#tutar').textContent(), '4.500,00 TL');
      assert.equal(await s.locator('#pos-no').textContent(), 'VP10000000000000001');
      assert.ok(!(s.url().includes('#')), 'İstek kimliği adres çubuğunda kalmamalı');
      await s.screenshot({ path: `/tmp/bup-pos-sonuc-${ad}.png` });
      // Kişi onaylamadan telefona bırakılmaz; onaylayınca kutuya bir kez girer.
      const kutu = () => uygulama.evaluate(() => JSON.parse(localStorage.getItem('bup-sonuc-kutusu') ?? '[]'));
      assert.deepEqual(await kutu(), []);
      await s.getByRole('button', { name: 'Bu cariye kaydet' }).click();
      await s.getByText(/Sonuç alındı: Örnek Yapay Market · 4\.500,00 TL/).waitFor();
      await pos.getByText(/Sanal POS sekmesine dönünce kendiliğinden kaydedilir/).waitFor();
      const [b1] = await kutu();
      assert.deepEqual({ ...b1, okunma: 0 }, { v: 1, uid: 'uid-1', girisId: 'A'.repeat(20), cariId: 'cari-1',
        cariAd: 'Örnek Yapay Market', kimlikNo: KIMLIK, kartSonDort: '1111', sonuc: 'basarili',
        aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: 'VP10000000000000001', uyeSiparisNo: '600001',
        tutarMetni: '4500', okunma: 0 });
      assert.ok(Math.abs(b1.okunma - Date.now()) < 60000);
      // Sanal POS sekmesi yazınca yanıtlar: sonuç sayfası ve DenizPay kutusu gösterir, sayfa kapanır.
      await uygulama.evaluate(() => { import('./sonuc_kutusu.js').then(() => bupSonucKutusu.yanitla(JSON.stringify(
        { posSiparisNo: 'VP10000000000000001', tamam: true, mesaj: 'Kaydedildi: Örnek Yapay Market · 4.500,00 TL', an: 1 }))); });
      await pos.getByText(/BUP Doldur: Kaydedildi: Örnek Yapay Market/).waitFor({ timeout: 8000 });
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
      // Sayfadaki firma başka cari: kaydedilmez, DenizPay sekmesindeki kutu da söyler.
      s = await sonucAc('/baska-onay.aspx');
      await s.getByText(/carisine ait değil/).waitFor({ timeout: 8000 });
      await pos.getByText(/carisine ait değil/).waitFor({ timeout: 8000 });
      assert.equal(await s.locator('#ozet').isHidden(), true);
      await s.close();
      // Son giriş yoksa (ör. elle girildi) sonuç bir cariye bağlanmaz.
      await uygulama.evaluate(() => bupAcikGiris.temizle());
      s = await sonucAc('/onay.aspx');
      await s.getByText(/açılmış bir DenizPay girişi yok/).waitFor({ timeout: 8000 });
      await s.close();
      // Başka site sonuç sayfasını açsa bile istek ona gitmez, özet beklenmez.
      await kotu.evaluate(() => { window.gelen = []; addEventListener('message', e => window.gelen.push(e.data)); });
      const [k3] = await Promise.all([baglam.waitForEvent('page'),
        kotu.evaluate(u => { window.open(`${u}/sonuc.html#b=${'d'.repeat(24)}&s=2`); }, UYGULAMA)]);
      await k3.getByText(/yanıt gelmedi/).waitFor({ timeout: 12000 });
      assert.deepEqual(await kotu.evaluate(() => window.gelen.filter(m => m?.tur?.startsWith('bup-sonuc'))), []);
      await k3.close();

      assert.deepEqual(harici, []);
      assert.deepEqual(hatalar, []);
      await baglam.close();
      console.log(`PASS ${ad}: kart yazma, CVV/tutar/düğmeye dokunmama, firma eşleşmesi, köken reddi, süre, sonuç ekranı okuma, ağ yalıtımı`);
    } finally { await tarayici.close(); }
  }
} finally { for (const s of sunucular) s.close(); }
