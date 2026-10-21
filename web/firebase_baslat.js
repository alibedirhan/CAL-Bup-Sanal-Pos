// Bu şablon yalnız canlı/emülatör derlemesinde bağlanır. Satır içi betik gerekmez.
try {
  await import('./kart_kasasi.js');
  await import('./pos_giris.js');
  await import('./doldurma.js');
  const base = 'https://www.gstatic.com/firebasejs/__FIREBASE_SDK_VERSION__/';
  window.firebase_core = await import(`${base}firebase-app.js`);
  window.firebase_auth = await import(`${base}firebase-auth.js`);
  window.firebase_firestore = await import(`${base}firebase-firestore-pipelines.js`);
  __EMULATOR_SETUP__
  const script = document.createElement('script');
  script.src = '__BOOTSTRAP_URL__';
  script.async = true;
  document.body.appendChild(script);
} catch {
  document.getElementById('acilis-metin').textContent = 'Giriş hizmeti yüklenemedi. İnternet bağlantını kontrol edip yeniden dene.';
  document.getElementById('yenile').hidden = false;
}
