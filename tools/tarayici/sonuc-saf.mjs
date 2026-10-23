import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

// Tarayıcısız birim testleri: sonuç ekranı okuma (Dart ile ortak örnekler), cari
// eşleştirme, telefondaki giriş listesi ve sonuç kutusu biçimi. Yapay veri.
const kok = fileURLToPath(new URL('../../', import.meta.url));
const depo = new Map();
globalThis.localStorage = {
  getItem: k => depo.has(k) ? depo.get(k) : null,
  setItem: (k, v) => depo.set(k, String(v)),
  removeItem: k => depo.delete(k),
};
const coz = await import(join(kok, 'web/sonuc_coz.js'));
const { cariEslestir, SURE } = await import(join(kok, 'web/cari_eslestir.js'));
const acik = await import(join(kok, 'web/acik_giris.js'));
const kutuModul = await import(join(kok, 'web/sonuc_kutusu.js'));
const ornekler = JSON.parse(readFileSync(join(kok, 'test/veri/tahsilat_ornekleri.json'), 'utf8'));

test('Tutar ve sonuç ekranı örnekleri (Dart ile ortak dosya)', () => {
  for (const [metin, kurus] of ornekler.tutarlar) assert.equal(coz.tutarCoz(metin), kurus, `tutar "${metin}"`);
  for (const o of ornekler.sonuclar) {
    const r = coz.sonucCoz(o.sayfa);
    if (o.beklenen.ok) assert.deepEqual(r, o.beklenen, o.ad); else assert.equal(r.ok, false, o.ad);
  }
  assert.equal(coz.tutarYaz(4567890), '45.678,90 TL');
  for (const [no, sonuc, kimlik] of ornekler.kimlikler) assert.equal(kutuModul.kimlik({ posSiparisNo: no, sonuc }), kimlik);
});

const T = Date.UTC(2026, 9, 22, 9, 0);
const dk = n => n * 60000;
const giris = (cari, vkn, an, ek = {}) => ({ v: 2, uid: 'u1', girisId: (cari + 'G'.repeat(20)).slice(0, 20).replace(/[^A-Za-z0-9]/g, 'X'),
  cariId: cari, cariAd: `Örnek ${cari}`, kimlikNo: vkn, kartSonDort: '', an, son: an + SURE, ...ek });
const A = '0000000001', B = '0000000002', C = '0000000003';
const a1 = giris('cariA', A, T - dk(60)), b1 = giris('cariB', B, T - dk(30));
const ozet = r => r.durum === 'kesin' ? ['kesin', r.giris.cariId, r.eslesme]
  : r.durum === 'secim' ? ['secim', r.adaylar.map(g => g.cariId)] : ['yok'];

test('Cari eşleştirme: kesin olmayan durumda kişiye seçtirilir', () => {
  const e = (l, firma = null, sekme = null) => ozet(cariEslestir(l, firma, sekme, T));
  assert.deepEqual(e([]), ['yok']);
  assert.deepEqual(e([a1]), ['kesin', 'cariA', 'tek_giris']);
  // Aynı cariye yeniden giriş tek cari sayılır; en son girişe bağlanır.
  const a2 = giris('cariA', A, T - dk(5), { girisId: 'H'.repeat(20) });
  const r = cariEslestir([a1, a2], null, null, T);
  assert.equal(r.durum, 'kesin'); assert.equal(r.giris.girisId, 'H'.repeat(20));
  // İki cari: son giriş önce listelenir, hiçbiri kendiliğinden seçilmez.
  assert.deepEqual(e([a1, b1]), ['secim', ['cariB', 'cariA']]);
  assert.match(cariEslestir([a1, b1], null, null, T).neden, /birden fazla cariyle/);
  // Sonuç ekranındaki firma numarası kesindir; tanınmayan firma kaydedilmez.
  assert.deepEqual(e([a1, b1], A), ['kesin', 'cariA', 'sonuc_ekrani']);
  assert.deepEqual(e([a1, b1], C), ['yok']);
  assert.deepEqual(e([a1, b1], B, { vkn: A, an: T - dk(1) }), ['kesin', 'cariB', 'sonuc_ekrani']);
  // Kart sayfası notu: o cariyle son girişten sonra başka cariyle girilmediyse kesin.
  assert.deepEqual(e([a1, b1], null, { vkn: B, an: T - dk(10) }), ['kesin', 'cariB', 'kart_sayfasi']);
  assert.deepEqual(e([a1], null, { vkn: A, an: T - dk(20) }), ['kesin', 'cariA', 'kart_sayfasi']);
  // Kart yazıldıktan sonra başka cariyle girildi: DenizPay oturumu değişmiş olabilir.
  assert.deepEqual(e([a1, b1], null, { vkn: A, an: T - dk(40) }), ['secim', ['cariB', 'cariA']]);
  assert.match(cariEslestir([a1, b1], null, { vkn: A, an: T - dk(40) }, T).neden, /sekmesi eski olabilir/);
  // Eski sekme: A ile girildi, sonra B ile; A'nın açık kalan sekmesine dönülüp yer imine yeniden
  // dokunuldu. Not yeni ama sekme eski: kesin denmez (0.10.0'da "kesin A" diyordu).
  assert.deepEqual(e([a1, b1], null, { vkn: A, an: T - dk(20) }), ['secim', ['cariB', 'cariA']]);
  assert.deepEqual(e([a1, b1], null, { vkn: A, an: T - dk(1) }), ['secim', ['cariB', 'cariA']]);
  // A ile yeniden girildiyse (yeni sekme) son giriş A'dır: yine kesin.
  const a4 = giris('cariA', A, T - dk(15), { girisId: 'K'.repeat(20) });
  const r4 = cariEslestir([a1, b1, a4], null, { vkn: A, an: T - dk(10) }, T);
  assert.deepEqual([r4.durum, r4.giris?.girisId, r4.eslesme], ['kesin', 'K'.repeat(20), 'kart_sayfasi']);
  assert.deepEqual(e([a1, b1], null, { vkn: C, an: T - dk(10) }), ['yok']);
  // 2 saatten eski veya gelecekteki not kullanılmaz.
  assert.deepEqual(e([a1, b1], null, { vkn: A, an: T - SURE - 1 }), ['secim', ['cariB', 'cariA']]);
  assert.deepEqual(e([a1, b1], null, { vkn: A, an: T + dk(5) }), ['secim', ['cariB', 'cariA']]);
  // Aynı VKN iki ayrı cari kaydında: firma numarası bile kesin değil.
  const a3 = giris('cariA3', A, T - dk(15));
  assert.deepEqual(e([a1, a3, b1], A), ['secim', ['cariA3', 'cariA']]);
  assert.deepEqual(e([a1, a3], null, { vkn: A, an: T - dk(1) }), ['secim', ['cariA3', 'cariA']]);
  // Yalnız son girişi yapan hesabın girişleri.
  assert.deepEqual(e([giris('cariX', C, T - dk(90), { uid: 'u0' }), a1]), ['kesin', 'cariA', 'tek_giris']);
});

test('Telefondaki giriş listesi: ekler, tekrar etmez, 10 ile ve 2 saatle sınırlı', () => {
  const g = globalThis.bupAcikGiris;
  depo.clear();
  const simdi = Date.now();
  const yeni = (n, an = simdi - dk(n)) => giris(`c${n}`, A, an, { girisId: `G${String(n).padStart(19, '0')}` });
  assert.equal(g.ekle(JSON.stringify(yeni(1))), 'ok');
  assert.equal(g.ekle(JSON.stringify(yeni(1))), 'ok'); // aynı giriş ikinci kez eklenmez
  assert.equal(g.oku().length, 1);
  for (let n = 2; n <= 12; n++) g.ekle(JSON.stringify(yeni(n)));
  const l = g.oku();
  assert.equal(l.length, 10);
  assert.ok(l.every((x, i) => i === 0 || l[i - 1].an <= x.an), 'eskiden yeniye');
  // Bozuk veya süresi geçmiş kayıt eklenmez; depodaki atılır.
  assert.throws(() => g.ekle(JSON.stringify({ ...yeni(13), v: 1 })));
  assert.throws(() => g.ekle(JSON.stringify({ ...yeni(14), son: simdi + SURE * 2 })));
  assert.throws(() => g.ekle(JSON.stringify(yeni(15, simdi - SURE - 1))));
  assert.throws(() => g.ekle(JSON.stringify({ ...yeni(16), numara: '4111111111111111' })));
  assert.throws(() => g.ekle('x'.repeat(3000)));
  depo.set('bup-acik-giris', JSON.stringify([yeni(17, simdi - SURE - 5), { v: 1 }, yeni(18)]));
  assert.deepEqual(g.oku().map(x => x.cariId), ['c18']);
  assert.equal(JSON.parse(depo.get('bup-acik-giris')).length, 1);
  depo.set('bup-acik-giris', '{bozuk');
  assert.deepEqual(g.oku(), []);
  // Başka hesapla giriş: yalnız o hesabın girişleri kalır.
  depo.set('bup-acik-giris', JSON.stringify([yeni(20), { ...yeni(21), uid: 'u2', girisId: 'H'.repeat(20) }]));
  g.yalniz('u2');
  assert.deepEqual(g.oku().map(x => x.uid), ['u2']);
  g.temizle();
  assert.equal(depo.has('bup-acik-giris'), false);
  assert.equal(acik.gecerli(yeni(19)), true);
});

test('Sonuç kutusu: 2. biçim eşleşme taşır, 1. biçim kabul edilir, 30 gün bekler', () => {
  const k = globalThis.bupSonucKutusu;
  depo.clear();
  const sonuc = (no, ek = {}) => ({ v: 2, uid: 'u1', girisId: 'G'.repeat(20), cariId: 'cariA', cariAd: 'Örnek A', kimlikNo: A,
    kartSonDort: '', sonuc: 'basarili', aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: no, uyeSiparisNo: '',
    tutarMetni: '4500', eslesme: 'kart_sayfasi', okunma: Date.now(), ...ek });
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0001'))), 'ok');
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0001', { cariId: 'cariB' }))), 'zaten');
  assert.equal(k.bul('VP0001').cariId, 'cariA');
  assert.equal(k.bul('VP9999'), null);
  for (const e of ['sonuc_ekrani', 'tek_giris', 'secim']) assert.equal(k.ekle(JSON.stringify(sonuc(`VP-${e}`.toUpperCase().replace('_', '-'), { eslesme: e }))), 'ok');
  const { eslesme, ...v1 } = sonuc('VP0002', { v: 1 });
  assert.equal(k.ekle(JSON.stringify(v1)), 'ok');
  for (const kotu of [{ eslesme: 'elle' }, { eslesme: 'son_giris' }, { eslesme: undefined }, { v: 1 }, { v: 3 },
    { okunma: Date.now() - 31 * 86400000 }, { okunma: Date.now() + 3600000 }, { numara: '4111111111111111' }]) {
    assert.throws(() => k.ekle(JSON.stringify(sonuc('VP0003', kotu))), JSON.stringify(kotu));
  }
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0004', { okunma: Date.now() - 29 * 86400000 }))), 'ok');
  assert.equal(JSON.parse(k.oku()).length, 6);
  assert.equal(kutuModul.gecerli(sonuc('VP0005')), true);
});

test('Sonuç kutusu: başarısız deneme ve aynı numaralı başarılı ödeme ayrı tutulur', () => {
  const k = globalThis.bupSonucKutusu;
  depo.clear();
  const sonuc = (no, ek = {}) => ({ v: 2, uid: 'u1', girisId: 'G'.repeat(20), cariId: 'cariA', cariAd: 'Örnek A', kimlikNo: A,
    kartSonDort: '', sonuc: 'basarili', aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: no, uyeSiparisNo: '',
    tutarMetni: '4500', eslesme: 'kart_sayfasi', okunma: Date.now(), ...ek });
  const hata = { sonuc: 'hata', aciklama: 'İşlem onaylanmadı.' };
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0101', hata))), 'ok');
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0101'))), 'ok');
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0101', hata))), 'zaten');
  assert.equal(k.ekle(JSON.stringify(sonuc('VP0101', { tutarMetni: '450' }))), 'zaten');
  assert.equal(k.bul('VP0101').sonuc, 'basarili');
  assert.equal(k.bul('VP0101-h').sonuc, 'hata');
  // Sanal POS kaydı kimlikle siler: başarısızı silmek başarılıya dokunmaz.
  k.sil('VP0101-h');
  assert.deepEqual(JSON.parse(k.oku()).map(x => kutuModul.kimlik(x)), ['VP0101']);
  k.sil('VP0101');
  assert.deepEqual(JSON.parse(k.oku()), []);
});

test('Sonuç kutusu Dart kadar sıkı: Sanal POS’un okuyamayacağı kayıt alınmaz', () => {
  const s = ek => ({ v: 2, uid: 'u1', girisId: 'G'.repeat(20), cariId: 'cariA', cariAd: 'Örnek A', kimlikNo: A,
    kartSonDort: '', sonuc: 'basarili', aciklama: 'Ödeme Başarıyla Gerçekleştirildi', posSiparisNo: 'VP0201', uyeSiparisNo: '',
    tutarMetni: '4500', eslesme: 'tek_giris', okunma: Date.now(), ...ek });
  for (const kotu of [{ aciklama: 'Ödeme\u200e' }, { tutarMetni: '4500\u2060' }, { aciklama: '   ' }, { cariAd: 'Ö\u202e' },
    { uyeSiparisNo: '60\u200b0' }, { tutarMetni: '\u00ad' }]) {
    assert.equal(kutuModul.gecerli(s(kotu)), false, JSON.stringify(kotu));
  }
  // sonuc_coz görünmezleri attığı için okunan sonuç kutuya girebilir.
  const r = coz.sonucCoz({ metin: 'Onay Formu', alanlar: [['Açıklama', 'Ödeme Başarıyla Gerçekleştirildi\u200e'],
    ['Pos Sipariş Numarası', 'VP\u200b0202'], ['Tutar', '4.500,00\u2060 TL']], firma: null, sekme: null });
  assert.equal(r.ok, true);
  assert.equal(kutuModul.gecerli(s({ aciklama: r.aciklama, posSiparisNo: r.posSiparisNo, tutarMetni: r.tutarMetni })), true);
  assert.equal(r.tutarKurus, 450000);
});
