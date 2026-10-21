// Telefon uyumluluk denemesinin Sanal POS tarafı. Bilgi doldurmaz, ağ isteği yapmaz.
// Derlemede tools/yer_imi/uret.py yer tutucuları doldurur.
const POS = '__POS_KOKENI__';
const YER_IMI = __YER_IMI__;
const $ = id => document.getElementById(id);
const kimlik = /^[0-9a-f]{24}$/;

const b = /^#b=([0-9a-f]{24})$/.exec(location.hash);
if (b) {
  // B kanalı: yer imi bu sayfayı açtı; yanıt yalnız DenizPay kökenine gider.
  $('ana-kip').hidden = true;
  $('b-kipi').hidden = false;
  history.replaceState(null, '', location.pathname);
  let acan = null;
  try { acan = window.opener; } catch { acan = null; }
  if (acan) {
    acan.postMessage({ tur: 'bup-deneme-yanit', id: b[1], kanal: 'B' }, POS);
    $('b-durum').textContent = 'Yanıt gönderildi. DenizPay sekmesine dönebilirsin.';
    setTimeout(() => window.close(), 1500);
  } else {
    $('b-durum').textContent = 'Açan sekme bulunamadı: B kanalı bu telefonda çalışmıyor. DenizPay sekmesine dönüp raporu kopyala.';
  }
} else {
  const ekran = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  $('kip').textContent = ekran ? 'ana ekran uygulaması' : 'tarayıcı sekmesi';
  $('kod').value = YER_IMI;
  $('kopyala').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(YER_IMI);
      $('kopya-durum').textContent = 'Kopyalandı. Şimdi aşağıdaki adımlarla yer imine yapıştır.';
    } catch {
      $('kod').select();
      $('kopya-durum').textContent = 'Kopyalanamadı. Kutudaki metni basılı tutup tamamını kopyala.';
    }
  });
  let pencere = null;
  $('ac').addEventListener('click', () => {
    // Açan sekme ilişkisi A kanalı için gereklidir; bu yüzden noopener kullanılmaz.
    pencere = window.open(POS + '/login.aspx', 'bupDenizPayDeneme');
    $('a-durum').textContent = pencere ? 'DenizPay açıldı, yer iminden mesaj bekleniyor' : 'Açılır pencere engellendi';
  });
  window.addEventListener('message', e => {
    if (!pencere || e.source !== pencere || e.origin !== POS) return;
    if (!e.data || e.data.tur !== 'bup-deneme-merhaba' || !kimlik.test(e.data.id)) return;
    pencere.postMessage({ tur: 'bup-deneme-yanit', id: e.data.id, kanal: 'A' }, POS);
    $('a-durum').textContent = 'Yer iminden mesaj geldi ve yanıtlandı';
  });
}
