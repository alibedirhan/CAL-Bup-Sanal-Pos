const acilis = document.getElementById('acilis');
const zamanAsimi = setTimeout(() => {
  const yazi = document.getElementById('acilis-metin');
  if (yazi) yazi.textContent = 'Açılış tamamlanamadı. Bağlantını kontrol edip yeniden deneyebilirsin.';
  const dugme = document.getElementById('yenile');
  if (dugme) dugme.hidden = false;
}, 20000);
document.getElementById('yenile').addEventListener('click', () => location.reload());
window.addEventListener('flutter-first-frame', () => {
  clearTimeout(zamanAsimi);
  window.__posReadyAt = performance.now();
  acilis.remove();
}, { once: true });
