// DenizPay kart sayfasındaki "BUP Doldur" yer iminin açtığı sayfa.
// Bekleyen işi (doldurma.js) okur, kartı cihaz kasasından çözer ve yalnız
// açan DenizPay sekmesine gönderir. Ağ isteği yapmaz; kart günlüğe yazılmaz.
// Derlemede tools/yer_imi/uret.py yer tutucuyu doldurur.
const POS = '__POS_KOKENI__';
// Yer imi kodu değişip eskisi artık uygun olmadığında bu sayı artırılır;
// tools/yer_imi/doldur.js SURUM_NO ile aynı tutulur. Numarasız ilk sürüm = 1.
const EN_AZ_YER_IMI = 1;
const $ = id => document.getElementById(id);
const b = /^#b=([0-9a-f]{24})(?:&s=([0-9]{1,3}))?$/.exec(location.hash);
history.replaceState(null, '', location.pathname);
let acan = null;
try { acan = window.opener; } catch { acan = null; }

const goster = (mesaj, hata = false) => {
  $('durum').textContent = mesaj;
  $('durum').className = hata ? 'hata' : '';
};
// targetOrigin sabit DenizPay'dir: açan sekme başka bir siteyse mesaj teslim edilmez.
const gonder = veri => acan.postMessage({ tur: 'bup-doldur-paket', id: b[1], ...veri }, POS);
const hata = mesaj => { gonder({ hata: mesaj }); goster(mesaj, true); };

if (!b || !acan) {
  goster('Bu sayfayı DenizPay kart sayfasında “BUP Doldur” yer imine dokunarak aç.', true);
} else {
  try {
    if (Number(b[2] ?? 1) < EN_AZ_YER_IMI) {
      throw new Error('eski');
    }
    await import('./doldurma.js');
    const is = globalThis.bupDoldurma.oku();
    if (!is) {
      hata('Bekleyen kart yok veya 10 dakikalık süre doldu. Sanal POS’ta cari ve kartı seçip “DenizPay’e giriş yap”a yeniden bas.');
    } else {
      await import('./kart_kasasi.js');
      const r = JSON.parse(await globalThis.bupKartKasasi.oku(is.uid, JSON.stringify(is.kart)));
      if (!r.ok || !r.value) {
        hata('Bu kartın tam bilgisi bu tarayıcıda yok. Kartı bu telefonda Safari/Chrome’da ekle ya da elle yaz.');
      } else {
        const p = JSON.parse(r.value);
        gonder({ kart: { numara: p.numara, ad: p.sahibi, ay: is.kart.ay, yil: is.kart.yil, kimlikNo: is.kimlikNo } });
        goster('Kart (•••• ' + is.kart.sonDort + ') DenizPay sekmesine gönderildi. Bu sekme kapanıyor; kapanmazsa DenizPay sekmesine dön.');
        setTimeout(() => window.close(), 700);
      }
    }
  } catch (e) {
    hata(e?.message === 'eski'
      ? 'Yer imin eski. Sanal POS → Çalışma alanı → “BUP Doldur yer imini kur” ile yeniden kur.'
      : 'Kart okunamadı. Sanal POS’u yenileyip yeniden dene ya da elle yaz.');
  }
}
