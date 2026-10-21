// "BUP Doldur" yer imi kurulum sayfası. Bilgi doldurmaz, ağ isteği yapmaz.
// Derlemede tools/yer_imi/uret.py yer tutucuyu doldurur.
const YER_IMI = __YER_IMI__;
const $ = id => document.getElementById(id);
$('kod').value = YER_IMI;
$('kopyala').addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(YER_IMI);
    $('kopya-durum').textContent = 'Kopyalandı. Şimdi 2. adımdaki gibi yer imine yapıştır.';
  } catch {
    $('kod').select();
    $('kopya-durum').textContent = 'Kopyalanamadı. Kutudaki metni basılı tutup tamamını kopyala.';
  }
});
