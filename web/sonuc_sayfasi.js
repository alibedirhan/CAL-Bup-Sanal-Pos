// DenizPay sonuç ekranındaki "BUP Doldur" yer iminin açtığı sayfa (yer imi 2+).
// Açan DenizPay sekmesinden sayfa özetini ister, sonucu okur (sonuc_coz.js),
// bu cihazdaki son girişin carisine bağlar (acik_giris.js) ve kişi onaylayınca
// sonuç kutusuna bırakır (sonuc_kutusu.js). Sunucuya Sanal POS sekmesi yazar:
// oturum yalnız o sekmededir. Ağ isteği yapmaz. Derlemede uret.py POS kökenini yazar.
import { sonucCoz, tutarYaz } from './sonuc_coz.js';
import './acik_giris.js';
import './sonuc_kutusu.js';

const POS = '__POS_KOKENI__';
const $ = id => document.getElementById(id);
const b = /^#b=([0-9a-f]{24})&s=([0-9]{1,3})$/.exec(location.hash);
history.replaceState(null, '', location.pathname);
let acan = null;
try { acan = window.opener; } catch { acan = null; }

const durum = (mesaj, tur = '') => { $('durum').textContent = mesaj; $('durum').className = tur; };
// DenizPay sekmesindeki yer imi kutusu da aynı sonucu gösterir (yalnız DenizPay kökenine).
const bildir = (mesaj, hata) => { try { acan?.postMessage({ tur: 'bup-sonuc-durum', id: b[1], mesaj, hata }, POS); } catch { /* sekme kapandı */ } };
const dur = mesaj => { durum(mesaj, 'hata'); bildir(mesaj, true); };

function isle(sayfa) {
  const r = sonucCoz(sayfa);
  if (!r.ok) { dur(r.hata); return; }
  const g = globalThis.bupAcikGiris.oku();
  if (!g) {
    dur('Bu telefonda son 2 saatte açılmış bir DenizPay girişi yok. Sanal POS’ta cariyi açıp “Ödeme sonucunu elle kaydet” ile kaydet.');
    return;
  }
  if (sayfa.firma && sayfa.firma !== g.kimlikNo) {
    dur(`Bu DenizPay oturumu ${g.cariAd} carisine ait değil. Kaydedilmedi; doğru cariyi Sanal POS’ta açıp elle kaydet.`);
    return;
  }
  const tutar = r.tutarKurus === null ? `${r.tutarMetni} (okunamadı)` : tutarYaz(r.tutarKurus);
  $('sonuc').textContent = r.sonuc === 'basarili' ? '✓ Ödeme başarılı' : '✗ Ödeme başarısız';
  $('sonuc').className = r.sonuc;
  $('cari').textContent = `${g.cariAd} · ${g.kimlikNo}`;
  $('tutar').textContent = tutar;
  $('pos-no').textContent = r.posSiparisNo;
  $('aciklama').textContent = r.aciklama;
  $('ozet').hidden = false;
  durum('Cari ve tutar doğruysa kaydet.');
  const dugme = $('kaydet');
  dugme.hidden = false;
  dugme.disabled = false;
  dugme.addEventListener('click', () => {
    dugme.hidden = true;
    let eklendi;
    try {
      eklendi = globalThis.bupSonucKutusu.ekle(JSON.stringify({
        v: 1, uid: g.uid, girisId: g.girisId, cariId: g.cariId, cariAd: g.cariAd, kimlikNo: g.kimlikNo,
        kartSonDort: g.kartSonDort, sonuc: r.sonuc, aciklama: r.aciklama, posSiparisNo: r.posSiparisNo,
        uyeSiparisNo: r.uyeSiparisNo, tutarMetni: r.tutarMetni, okunma: Date.now(),
      }));
    } catch {
      dugme.hidden = false;
      dur('Sonuç bu telefona yazılamadı. Sanal POS’ta “Ödeme sonucunu elle kaydet” ile kaydet.');
      return;
    }
    const ozet = `${g.cariAd} · ${tutar}`;
    const bekliyor = `Sonuç alındı: ${ozet}. Sanal POS sekmesine dönünce kendiliğinden kaydedilir.`;
    durum(eklendi === 'zaten' ? `Bu sonuç zaten alınmıştı: ${ozet}.` : bekliyor, 'tamam');
    bildir(bekliyor, false);
    // Sanal POS sekmesi açık ve çalışıyorsa hemen yazar ve yanıtlar.
    globalThis.bupSonucKutusu.yanitDinle(json => {
      let y = null;
      try { y = JSON.parse(json); } catch { return; }
      if (y?.posSiparisNo !== r.posSiparisNo || typeof y.mesaj !== 'string') return;
      durum(y.mesaj.slice(0, 300), y.tamam === true ? 'tamam' : 'hata');
      bildir(y.mesaj.slice(0, 300), y.tamam !== true);
      if (y.tamam === true) setTimeout(() => window.close(), 2500);
    });
  });
}

if (!b || !acan) {
  durum('Bu sayfayı DenizPay sonuç ekranında “BUP Doldur” yer imine dokunarak aç.', 'hata');
} else if (Number(b[2]) < 2) {
  dur('Yer imin eski. Sanal POS → Çalışma alanı → “BUP Doldur yer imini kur” ile yeniden kur.');
} else {
  let alindi = false;
  // Yalnız açan DenizPay sekmesinden ve bu istek kimliğiyle gelen özet işlenir.
  window.addEventListener('message', e => {
    if (alindi || e.source !== acan || e.origin !== POS || e.data?.tur !== 'bup-sonuc-paket' || e.data.id !== b[1]) return;
    alindi = true;
    try { isle(e.data.sayfa); } catch { dur('Sonuç işlenemedi. Sanal POS’ta elle kaydet.'); }
  });
  acan.postMessage({ tur: 'bup-sonuc-iste', id: b[1] }, POS);
  setTimeout(() => { if (!alindi) dur('DenizPay sekmesinden yanıt gelmedi. Sonuç ekranında yer imine yeniden dokun.'); }, 8000);
}
