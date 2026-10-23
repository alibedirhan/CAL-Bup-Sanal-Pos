// DenizPay sonuç ekranındaki "BUP Doldur" yer iminin açtığı sayfa (yer imi 3+).
// Açan DenizPay sekmesinden sayfa özetini ister, sonucu okur (sonuc_coz.js),
// bu telefondaki girişlerden doğru cariyi belirler (cari_eslestir.js) ve kişi
// onaylayınca sonuç kutusuna bırakır (sonuc_kutusu.js). Cari kesin değilse
// adaylar gösterilir, kişi seçmeden kaydedilmez. Sunucuya Sanal POS sekmesi
// yazar: oturum yalnız o sekmededir. Ağ isteği yapmaz. Derlemede uret.py POS
// kökenini yazar.
import { sonucCoz, tutarCoz, tutarYaz } from './sonuc_coz.js';
import { cariEslestir } from './cari_eslestir.js';
import './acik_giris.js';
import { kimlik } from './sonuc_kutusu.js';

const POS = '__POS_KOKENI__';
// Sekme notu ve sayfa özeti biçimi 3. sürümde geldi; eski yer imi yeniden kurulur.
const EN_AZ_YER_IMI = 3;
const $ = id => document.getElementById(id);
const b = /^#b=([0-9a-f]{24})&s=([0-9]{1,3})$/.exec(location.hash);
history.replaceState(null, '', location.pathname);
let acan = null;
try { acan = window.opener; } catch { acan = null; }

const durum = (mesaj, tur = '') => { $('durum').textContent = mesaj; $('durum').className = tur; };
// DenizPay sekmesindeki yer imi kutusu da aynı sonucu gösterir (yalnız DenizPay kökenine).
const bildir = (mesaj, hata) => { try { acan?.postMessage({ tur: 'bup-sonuc-durum', id: b[1], mesaj, hata }, POS); } catch { /* sekme kapandı */ } };
const dur = mesaj => { durum(mesaj, 'hata'); bildir(mesaj, true); };
const saat = an => new Date(an).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' });
const ESLESME = {
  sonuc_ekrani: 'Cari, DenizPay sonuç ekranındaki firma numarasıyla doğrulandı.',
  kart_sayfasi: 'Cari, bu DenizPay sekmesinin kart sayfasındaki firma numarasıyla doğrulandı.',
  tek_giris: 'Son 2 saatte bu telefonda yalnız bu cariyle DenizPay’e girildi.',
};

// Seçim: her aday için bir seçenek; hiçbiri önceden seçili değildir.
function adaylariGoster(adaylar, neden, secilince) {
  $('secim-neden').textContent = neden;
  const kutu = $('adaylar');
  kutu.replaceChildren(...adaylar.map((g, i) => {
    const etiket = document.createElement('label');
    const secenek = document.createElement('input');
    secenek.type = 'radio';
    secenek.name = 'cari';
    secenek.value = String(i);
    secenek.addEventListener('change', () => secilince(g));
    const ad = document.createElement('strong');
    ad.textContent = g.cariAd;
    const ek = document.createElement('span');
    ek.textContent = `VKN / TC ${g.kimlikNo} · giriş ${saat(g.an)}${i === 0 ? ' (son giriş)' : ''}`;
    etiket.append(secenek, ad, ek);
    return etiket;
  }));
  $('secim').hidden = false;
}

function isle(sayfa) {
  const r = sonucCoz(sayfa);
  if (!r.ok) { dur(r.hata); return; }
  const e = cariEslestir(globalThis.bupAcikGiris.oku(), sayfa.firma, sayfa.sekme);
  if (e.durum === 'yok') { dur(e.hata); return; }
  const tutar = r.tutarKurus === null ? `${r.tutarMetni} (okunamadı)` : tutarYaz(r.tutarKurus);
  $('sonuc').textContent = r.sonuc === 'basarili' ? '✓ Ödeme başarılı' : '✗ Ödeme başarısız';
  $('sonuc').className = r.sonuc;
  $('tutar').textContent = tutar;
  $('pos-no').textContent = r.posSiparisNo;
  $('aciklama').textContent = r.aciklama;
  $('ozet').hidden = false;
  const dugme = $('kaydet');
  let secilen = null;
  if (e.durum === 'kesin') {
    secilen = e.giris;
    $('cari').textContent = `${secilen.cariAd} · ${secilen.kimlikNo}`;
    $('eslesme').textContent = ESLESME[e.eslesme];
    durum('Cari ve tutar doğruysa kaydet.');
    dugme.disabled = false;
  } else {
    $('cari').textContent = 'Seçilmedi';
    adaylariGoster(e.adaylar, e.neden, g => {
      secilen = g;
      $('cari').textContent = `${g.cariAd} · ${g.kimlikNo}`;
      dugme.disabled = false;
    });
    dugme.textContent = 'Seçili cariye kaydet';
    durum('Cariyi seç, tutarı kontrol et, sonra kaydet.');
    bildir('Sonuç sayfasında ödemenin ait olduğu cariyi seç.', false);
  }
  dugme.hidden = false;
  dugme.addEventListener('click', () => {
    if (!secilen) return;
    const g = secilen, eslesme = e.durum === 'kesin' ? e.eslesme : 'secim';
    dugme.hidden = true;
    $('secim').hidden = true;
    let eklendi;
    try {
      eklendi = globalThis.bupSonucKutusu.ekle(JSON.stringify({
        v: 2, uid: g.uid, girisId: g.girisId, cariId: g.cariId, cariAd: g.cariAd, kimlikNo: g.kimlikNo,
        kartSonDort: g.kartSonDort, sonuc: r.sonuc, aciklama: r.aciklama, posSiparisNo: r.posSiparisNo,
        uyeSiparisNo: r.uyeSiparisNo, tutarMetni: r.tutarMetni, eslesme, okunma: Date.now(),
      }));
    } catch {
      dugme.hidden = false;
      dur('Sonuç bu telefona yazılamadı. Sanal POS’ta “Ödeme sonucunu elle kaydet” ile kaydet.');
      return;
    }
    const ozet = `${g.cariAd} · ${tutar}`;
    const bekliyor = `Sonuç alındı: ${ozet}. Sanal POS sekmesine dön (şifre sorarsa gir); kayıt kendiliğinden yapılır.`;
    const k = kimlik(r);
    if (eklendi === 'zaten') {
      // Sunucuya yazılmamış ilk sonuç değiştirilmez; cari veya tutar farklıysa açıkça söylenir.
      const once = globalThis.bupSonucKutusu.bul(k);
      if (once && once.cariId !== g.cariId) {
        dur(`Bu sonuç daha önce ${once.cariAd} carisi için alındı ve değiştirilemez. Yanlışsa kaydı yöneticine bildir.`);
        return;
      }
      // Dart ayniOdeme ile aynı: iki tutar da okunabiliyorsa kuruşla, değilse yazıyla.
      const a = tutarCoz(once?.tutarMetni), b = r.tutarKurus;
      if (once && (a !== null && b !== null ? a !== b : once.tutarMetni !== r.tutarMetni)) {
        dur(`Dikkat: Pos No ${r.posSiparisNo} daha önce ${once.tutarMetni} tutarıyla alındı; bu ekranda ${r.tutarMetni} yazıyor. Kaydedilmedi; DenizPay ekranını kontrol edip yöneticine bildir.`);
        return;
      }
      durum(`Bu sonuç zaten alınmıştı: ${ozet}. Sanal POS’a dönünce kaydedilir.`, 'tamam');
    } else {
      durum(bekliyor, 'tamam');
    }
    bildir(eklendi === 'zaten' ? `Bu sonuç zaten alınmıştı: ${ozet}.` : bekliyor, false);
    // Sanal POS sekmesi açık ve çalışıyorsa hemen yazar ve yanıtlar.
    globalThis.bupSonucKutusu.yanitDinle(json => {
      let y = null;
      try { y = JSON.parse(json); } catch { return; }
      if (y?.kimlik !== k || typeof y.mesaj !== 'string') return;
      durum(y.mesaj.slice(0, 300), y.tamam === true ? 'tamam' : 'hata');
      bildir(y.mesaj.slice(0, 300), y.tamam !== true);
      if (y.tamam === true) setTimeout(() => window.close(), 2500);
    });
  });
}

if (!b || !acan) {
  durum('Bu sayfayı DenizPay sonuç ekranında “BUP Doldur” yer imine dokunarak aç.', 'hata');
} else if (Number(b[2]) < EN_AZ_YER_IMI) {
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
