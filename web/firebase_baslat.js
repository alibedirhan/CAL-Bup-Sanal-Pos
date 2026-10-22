// Bu şablon yalnız canlı/emülatör derlemesinde bağlanır. Satır içi betik gerekmez.
try {
  // Modüller birbirini beklemeden aynı anda yüklenir (açılış süresi); SDK
  // modülleri ortak firebase-app'i tarayıcının modül önbelleğinden paylaşır.
  const base = 'https://www.gstatic.com/firebasejs/__FIREBASE_SDK_VERSION__/';
  const [sdkCore, sdkAuth, sdkFirestore] = await Promise.all([
    import(`${base}firebase-app.js`),
    import(`${base}firebase-auth.js`),
    import(`${base}firebase-firestore-pipelines.js`),
    import('./kart_kasasi.js'),
    import('./pos_giris.js'),
    import('./doldurma.js'),
    import('./acik_giris.js'),
    import('./sonuc_kutusu.js'),
  ]);
  window.firebase_core = sdkCore;
  window.firebase_auth = sdkAuth;
  window.firebase_firestore = sdkFirestore;
  __EMULATOR_SETUP__
  const script = document.createElement('script');
  script.src = '__BOOTSTRAP_URL__';
  script.async = true;
  document.body.appendChild(script);
} catch {
  document.getElementById('acilis-metin').textContent = 'Giriş hizmeti yüklenemedi. İnternet bağlantını kontrol edip yeniden dene.';
  document.getElementById('yenile').hidden = false;
}
