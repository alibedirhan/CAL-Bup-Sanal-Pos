// DenizPay sonucunun hangi cariye ait olduğunu belirler. Saf işlev: depo, ağ,
// sayfa yok. Eşleşme kodları lib/domain/tahsilat.dart CariEslesmesi ve
// firestore.rules ile aynıdır; kayıtta denetim izi olarak saklanır.
//
// Girdiler:
// - girisler: bu telefonda son 2 saatte "DenizPay'e giriş yap"a basılan cariler
//   (acik_giris.js; eskiden yeniye).
// - sayfaFirma: sonuç ekranının kendisinde yazan firma VKN/TC'si (yoksa null).
// - sekme: aynı DenizPay sekmesinde, kart sayfasında yer iminin okuduğu firma
//   numarası ve anı {vkn, an} (yoksa null). Kart sayfası DenizPay'in o sekmede
//   hangi firmayla açık olduğunu gösterir.
//
// Kesin değilse kayıt kendiliğinden yapılmaz: adaylar gösterilir, kişi seçer.
export const SURE = 2 * 60 * 60 * 1000;

const kesin = (giris, eslesme) => ({ durum: 'kesin', giris, eslesme });
const secim = (adaylar, neden) => ({ durum: 'secim', adaylar, neden });
const yok = hata => ({ durum: 'yok', hata });

// Her carinin en son girişi, yeniden eskiye.
function cariler(l) {
  const m = new Map();
  for (const g of [...l].sort((a, b) => a.an - b.an)) m.set(g.cariId, g);
  return [...m.values()].sort((a, b) => b.an - a.an);
}

export function cariEslestir(girisler, sayfaFirma, sekme, simdi = Date.now()) {
  if (!Array.isArray(girisler) || girisler.length === 0) {
    return yok('Bu telefonda son 2 saatte açılmış bir DenizPay girişi yok. Sanal POS’ta cariyi açıp “Ödeme sonucunu elle kaydet” ile kaydet.');
  }
  // Liste hesap değişiminde silinir; yine de yalnız son girişi yapan hesabınkiler.
  const uid = [...girisler].sort((a, b) => a.an - b.an).at(-1).uid;
  const l = girisler.filter(g => g.uid === uid);
  if (sayfaFirma) {
    const a = cariler(l.filter(g => g.kimlikNo === sayfaFirma));
    if (a.length === 0) {
      return yok(`Bu DenizPay ekranındaki firma (${sayfaFirma}) bu telefonda son 2 saatte girilen carilerden değil. Kaydedilmedi; doğru cariyi Sanal POS’ta açıp elle kaydet.`);
    }
    return a.length === 1 ? kesin(a[0], 'sonuc_ekrani') : secim(a, 'Bu VKN / TC ile birden fazla cari var. Ödemenin ait olduğu cariyi seç.');
  }
  // Kart sayfası notu 2 saatten eskiyse kullanılmaz (DenizPay oturumu değişmiş olabilir).
  const not = sekme && sekme.an <= simdi + 60000 && simdi - sekme.an < SURE ? sekme : null;
  if (not) {
    const a = cariler(l.filter(g => g.kimlikNo === not.vkn));
    if (a.length === 0) {
      return yok(`Bu DenizPay sekmesi ${not.vkn} numaralı firmayla açık; bu telefonda son 2 saatte o cariyle giriş yok. Kaydedilmedi; doğru cariyi Sanal POS’ta açıp elle kaydet.`);
    }
    // Kart yazıldıktan sonra başka cariyle girildiyse DenizPay oturumu değişmiş olabilir.
    const sonra = l.filter(g => g.kimlikNo !== not.vkn && g.an > not.an);
    if (a.length === 1 && sonra.length === 0) return kesin(a[0], 'kart_sayfasi');
    return secim(cariler([...a, ...sonra]), sonra.length
      ? 'Bu sekmede kart yazıldıktan sonra başka cariyle de DenizPay’e girildi. Ödemeyi hangi cari için aldıysan onu seç.'
      : 'Bu VKN / TC ile birden fazla cari var. Ödemenin ait olduğu cariyi seç.');
  }
  const a = cariler(l);
  return a.length === 1 ? kesin(a[0], 'tek_giris') : secim(a,
    'Son 2 saatte bu telefonda birden fazla cariyle DenizPay’e girildi. Ödemeyi hangi cari için aldıysan onu seç.');
}
