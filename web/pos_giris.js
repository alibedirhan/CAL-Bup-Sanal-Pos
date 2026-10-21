// Yalnız kullanıcı tıklamasında, sabit DenizPay giriş adresine geçici form POST'u.
// Gönderimi tarayıcı yapar; yanıt okunmaz, değerler saklanmaz veya günlüğe yazılmaz.
// Alan adları CAL bup platform/posGiris.ts ile aynıdır (kullanıcı orada çalıştığını bildirdi).
const HEDEF = 'https://denizpay.bupilic.com.tr/login.aspx';
const numara = v => typeof v === 'string' && /^[0-9]{10,11}$/.test(v);
globalThis.bupPosGiris = Object.freeze({
  ac(vergiNo, kullanici, sifre) {
    if (!numara(vergiNo) || !numara(kullanici) || typeof sifre !== 'string' || !/^[0-9]{4}$/.test(sifre)) {
      throw new Error('pos_giris');
    }
    const form = document.createElement('form');
    form.method = 'post';
    form.action = HEDEF;
    form.target = '_blank';
    form.rel = 'noopener noreferrer';
    form.acceptCharset = 'UTF-8';
    form.autocomplete = 'off';
    form.hidden = true;
    // ASP.NET'in isteği giriş gönderimi olarak işlemesi için boş durum alanı;
    // sağlayıcının imzalı sayfa/oturum değerleri kopyalanmaz.
    for (const [ad, deger] of [['__VIEWSTATE', ''], ['lvergino', vergiNo], ['lkullaniciadi', kullanici],
      ['lsifre', sifre], ['btngiris', 'Giriş Yap']]) {
      const alan = document.createElement('input');
      alan.type = 'hidden';
      alan.name = ad;
      alan.value = deger;
      form.append(alan);
    }
    const temizle = () => {
      for (const alan of form.elements) alan.value = '';
      form.remove();
    };
    try {
      document.body.append(form);
      form.submit();
    } catch (e) {
      temizle();
      throw e;
    }
    // CAL bup ile aynı: gezinme başladıktan sonra DOM'da değer bırakılmaz.
    setTimeout(temizle, 0);
    return 'ok';
  },
});
