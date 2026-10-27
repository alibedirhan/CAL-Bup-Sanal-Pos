/// Uygulama içi DenizPay sayfasında çalışan betik. Yalnız DenizPay kökeninde
/// ve yalnız uygulama istediğinde çalıştırılır (banka sayfalarına eklenmez).
/// Kurallar web yer imiyle (`tools/yer_imi/doldur.js`) aynıdır: yalnız tek ve
/// görünür `number`, `name`, `expiry` kutularına yazar; CVV, tutar, düğme ve
/// form gönderimine dokunmaz; sayfadaki "Firma İsmi" numarası seçili carinin
/// VKN/TC'si değilse hiçbir şey yazmaz. Ağ isteği yapmaz, uzaktan kod yüklemez,
/// hiçbir şeyi saklamaz veya günlüğe yazmaz.
///
/// Çağrı: `betik(istek)`; istek `{tur: 'ozet'}` ya da `{tur: 'yaz', kart}`.
/// Dönen değer JSON metnidir. `__KOKEN__` derlemede DenizPay kökeniyle değişir.
const denizPayBetigi = r'''
(function (istek) {
  if (location.origin !== '__KOKEN__') { return JSON.stringify({ hata: 'sayfa' }); }
  var ENGEL = /tutar|amount|taksit|sms|otp|sifre|parola|password|cvv|cvc|csc|cv2|guvenlik|security|pin/i;
  var alan = function (ad) {
    var l = Array.prototype.filter.call(document.getElementsByName(ad), function (e) { return e.tagName === 'INPUT'; });
    if (l.length !== 1) { return null; }
    var e = l[0];
    var ipucu = [e.name, e.id, e.getAttribute('autocomplete'), e.placeholder, e.getAttribute('aria-label')].join(' ');
    if (['text', 'tel'].indexOf(e.type) < 0 || e.disabled || e.readOnly || !e.getClientRects().length || ENGEL.test(ipucu)) { return null; }
    return e;
  };
  var firma = function () {
    var m = /Firma\s*[İI]smi\s*:?[^(\n]*\(\s*([0-9]{10,11})\s*\)/.exec(document.body.innerText);
    return m ? m[1] : null;
  };
  var luhn = function (n) {
    var t = 0, cift = false;
    for (var i = n.length - 1; i >= 0; i--, cift = !cift) { var r = Number(n[i]); if (cift) { r *= 2; if (r > 9) { r -= 9; } } t += r; }
    return t > 0 && t % 10 === 0;
  };
  var k = { numara: alan('number'), ad: alan('name'), skt: alan('expiry') };
  var kartSayfasi = !!(k.numara && k.skt);
  if (istek.tur === 'ozet') {
    var alanlar = [];
    // Kart sayfasında kutuların yazısı okunmaz (kart sahibi adı vb. uygulamaya geçmez).
    if (!kartSayfasi) {
      var son = '';
      var gez = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
      for (var n = gez.nextNode(); n && alanlar.length < 40; n = gez.nextNode()) {
        if (n.nodeType === 3) {
          var x = n.nodeValue.replace(/\s+/g, ' ').trim();
          if (x && ['SCRIPT', 'STYLE'].indexOf(n.parentNode.tagName) < 0) { son = x.slice(0, 80); }
        } else if ((n.tagName === 'INPUT' && ['hidden', 'password', 'checkbox', 'radio', 'submit', 'button', 'image', 'file'].indexOf(n.type) < 0) || n.tagName === 'TEXTAREA') {
          var v = String(n.value).replace(/\s+/g, ' ').trim().slice(0, 200);
          var rakam = v.replace(/[ -]/g, '');
          if (v && !(/^[0-9 -]+$/.test(v) && rakam.length >= 13 && rakam.length <= 19 && luhn(rakam))) { alanlar.push([son, v]); }
        }
      }
    }
    return JSON.stringify({ metin: kartSayfasi ? '' : document.body.innerText.slice(0, 5000), alanlar: alanlar, firma: firma(), kartAlanlari: kartSayfasi });
  }
  if (istek.tur !== 'yaz') { return JSON.stringify({ hata: 'istek' }); }
  var c = istek.kart || {};
  var gecerli = typeof c.numara === 'string' && /^[0-9]{12,19}$/.test(c.numara) && luhn(c.numara) &&
    c.ay >= 1 && c.ay <= 12 && c.yil >= 2000 && c.yil <= 2199 &&
    typeof c.ad === 'string' && c.ad.length <= 120 && !/[\x00-\x1f]/.test(c.ad) &&
    typeof c.kimlikNo === 'string' && /^[0-9]{10,11}$/.test(c.kimlikNo);
  if (!gecerli) { return JSON.stringify({ sonuc: 'gecersiz' }); }
  if (!kartSayfasi) { return JSON.stringify({ sonuc: 'kutu' }); }
  if (firma() !== c.kimlikNo) { return JSON.stringify({ sonuc: 'firma' }); }
  var grupla = function (n) {
    var boy = /^3[47]/.test(n) ? [4, 6, 5] : [4, 4, 4, 4, 3];
    var p = [], i = 0;
    boy.forEach(function (b) { if (i < n.length) { p.push(n.slice(i, i + b)); i += b; } });
    return p.join(' ');
  };
  var yaz = function (e, v) {
    var ayar = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    e.focus();
    ayar.call(e, v);
    ['input', 'change', 'keyup'].forEach(function (t) { e.dispatchEvent(new Event(t, { bubbles: true })); });
    e.blur();
  };
  yaz(k.numara, grupla(c.numara));
  if (k.ad && c.ad) { yaz(k.ad, c.ad); }
  yaz(k.skt, String(c.ay).padStart(2, '0') + ' / ' + String(c.yil).slice(-2));
  return JSON.stringify({ sonuc: k.numara.value.replace(/[^0-9]/g, '') === c.numara ? 'tamam' : 'eksik' });
})
''';
