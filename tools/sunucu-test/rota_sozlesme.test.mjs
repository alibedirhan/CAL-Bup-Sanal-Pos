// Sözleşme doğrulayıcısı (docs/rota/sozlesme) Kotlin'in ürettiği örnekle ve bozuk örneklerle.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { parcaDogrula, bosluklar, terminalKodu } from '../../docs/rota/sozlesme/dogrula.mjs';

const ornek = JSON.parse(await readFile(new URL('../../docs/rota/sozlesme/parca-ornek.json', import.meta.url), 'utf8'));
const kimlik = `${ornek.cihaz}_${ornek.ilk}`;

test('Kotlin örneği geçerli', () => {
  const r = parcaDogrula(ornek, kimlik);
  assert.deepEqual(r.hatalar, []);
  assert.equal(r.gecerli, true);
  assert.deepEqual(r.noktalar.map(n => n.q), [41, 44]);
  assert.deepEqual(r.olaylar.map(o => o.tur), ['konum_kapandi', 'kurulum']);
  assert.deepEqual(r.noktalar.map(n => n.o), [18250, null]);
  assert.equal(r.atlanan, 0);
});

test('Bozuk nokta atlanır, parça düşmez; bozuk parça düşer', () => {
  const p = structuredClone(ornek);
  p.n[0].en = 123;
  p.olaylar[0].tur = '<script>';
  const r = parcaDogrula(p, kimlik);
  assert.equal(r.atlanan, 2);
  assert.equal(r.noktalar.length, 1);
  for (const bozuk of [{ ...ornek, s: 2 }, { ...ornek, ilk: 40 }, { ...ornek, n: 'x' }])
    assert.equal(parcaDogrula(bozuk, kimlik).gecerli, false);
  const cift = structuredClone(ornek);
  cift.n[1].q = 41;
  assert.equal(parcaDogrula(cift, kimlik).gecerli, false);
});

test('Km sayacı isteğe bağlı; bozuksa yalnız o nokta atlanır', () => {
  const eski = structuredClone(ornek);
  for (const n of eski.n) delete n.o;
  assert.equal(parcaDogrula(eski, kimlik).noktalar.length, 2);
  for (const bozuk of [-1, 1.5, '12', 1e11]) {
    const p = structuredClone(ornek);
    p.n[0].o = bozuk;
    const r = parcaDogrula(p, kimlik);
    assert.equal(r.gecerli, true);
    assert.equal(r.atlanan, 1);
  }
});

test('Parçalar arası boşluk bulunur', () => {
  assert.deepEqual(bosluklar([{ ilk: 1, son: 5 }, { ilk: 6, son: 9 }, { ilk: 14, son: 20 }]), [{ ilk: 10, son: 13 }]);
});

test('Terminal kodu Kotlin ile aynı', async () => {
  assert.equal(await terminalKodu('terminalBir0000000000000001'), 'K9WMEY');
});
