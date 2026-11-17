// Rota yönetici aracının Firestore REST katmanı. Canlıda Firebase CLI oturumuyla (bulut.mjs; admin
// SDK'nın Firestore istemcisi bu oturumla çalışmaz), emülatörde "owner" yetkisiyle. İki ortamda aynı
// kod çalışır: emülatörde sınanan, canlıda koşan koddur.
export async function rotaRest({ emulator }) {
  let proje, istek;
  if (emulator) {
    proje = 'demo-bup-pos';
    const kok = `http://${process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088'}`;
    istek = async (yol, { method = 'GET', body } = {}) => {
      const r = await fetch(kok + yol, { method, headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: r.status, data: await r.json() };
    };
  } else {
    const { cloudFetch, projectId } = await import('./bulut.mjs');
    proje = projectId;
    istek = (yol, o) => cloudFetch(`https://firestore.googleapis.com${yol}`, o);
  }
  const db = `/v1/projects/${proje}/databases/(default)`;
  const belgeAdi = yol => `projects/${proje}/databases/(default)/documents/${yol}`;
  const tamam = (r, ne) => {
    if (r.status !== 200) throw Error(`${ne} başarısız: ${r.status} ${r.data?.error?.status ?? ''} ${r.data?.error?.message ?? ''}`);
    return r.data;
  };

  const yaz = v => v === null ? { nullValue: null }
    : typeof v === 'boolean' ? { booleanValue: v }
    : Number.isInteger(v) ? { integerValue: String(v) }
    : typeof v === 'number' ? { doubleValue: v }
    : typeof v === 'string' ? { stringValue: v }
    : Array.isArray(v) ? { arrayValue: { values: v.map(yaz) } }
    : { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, yaz(x)])) } };
  const oku = v => 'nullValue' in v ? null : 'booleanValue' in v ? v.booleanValue
    : 'integerValue' in v ? Number(v.integerValue) : 'doubleValue' in v ? v.doubleValue
    : 'stringValue' in v ? v.stringValue : 'timestampValue' in v ? new Date(v.timestampValue)
    : 'arrayValue' in v ? (v.arrayValue.values ?? []).map(oku)
    : 'mapValue' in v ? alanlar(v.mapValue.fields ?? {}) : undefined;
  const alanlar = f => Object.fromEntries(Object.entries(f).map(([k, v]) => [k, oku(v)]));
  const belge = d => ({ id: d.name.split('/').pop(), veri: alanlar(d.fields ?? {}) });

  return {
    /** Tek belge; yoksa null. */
    async al(yol) {
      const r = await istek(`${db}/documents/${yol}`);
      if (r.status === 404) return null;
      return belge(tamam(r, 'Okuma'));
    },
    /** Koleksiyonun bütün belgeleri (sayfalı). */
    async liste(koleksiyon) {
      const sonuc = [];
      let sayfa = '';
      do {
        const d = tamam(await istek(`${db}/documents/${koleksiyon}?pageSize=300${sayfa ? `&pageToken=${sayfa}` : ''}`), 'Liste');
        sonuc.push(...(d.documents ?? []).map(belge));
        sayfa = d.nextPageToken ?? '';
      } while (sayfa);
      return sonuc;
    },
    /** alan == değer sorgusu. */
    async esit(koleksiyon, alan, deger, sinir) {
      const d = tamam(await istek(`${db}/documents:runQuery`, { method: 'POST', body: { structuredQuery: {
        from: [{ collectionId: koleksiyon }],
        where: { fieldFilter: { field: { fieldPath: alan }, op: 'EQUAL', value: yaz(deger) } },
        ...(sinir ? { limit: sinir } : {}),
      } } }), 'Sorgu');
      return d.filter(x => x.document).map(x => belge(x.document));
    },
    async say(koleksiyon, alan, deger) {
      const d = tamam(await istek(`${db}/documents:runAggregationQuery`, { method: 'POST', body: { structuredAggregationQuery: {
        structuredQuery: { from: [{ collectionId: koleksiyon }],
          where: { fieldFilter: { field: { fieldPath: alan }, op: 'EQUAL', value: yaz(deger) } } },
        aggregations: [{ alias: 'n', count: {} }],
      } } }), 'Sayım');
      return Number(d[0]?.result?.aggregateFields?.n?.integerValue ?? 0);
    },
    /**
     * Toplu yazma. Her öğe: { yol, veri, zamanlar: [sunucu saatine ayarlanacak alanlar],
     * birlestir: true ise yalnız verilen alanlar değişir, yeni: true ise belge yoksa yazılır }.
     */
    async toplu(yazmalar) {
      tamam(await istek(`${db}/documents:commit`, { method: 'POST', body: { writes: yazmalar.map(w => ({
        update: { name: belgeAdi(w.yol), fields: Object.fromEntries(Object.entries(w.veri).map(([k, v]) => [k, yaz(v)])) },
        ...(w.birlestir ? { updateMask: { fieldPaths: Object.keys(w.veri) } } : {}),
        ...(w.yeni ? { currentDocument: { exists: false } } : {}),
        updateTransforms: (w.zamanlar ?? []).map(f => ({ fieldPath: f, setToServerValue: 'REQUEST_TIME' })),
      })) } }), 'Yazma');
    },
  };
}
