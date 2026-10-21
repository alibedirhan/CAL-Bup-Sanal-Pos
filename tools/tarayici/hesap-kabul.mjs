import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { chromium, webkit } from 'playwright';
import { fixture, parola } from '../sunucu-test/fixture.mjs';

await mkdir('/tmp/bup-pos-qa-02',{recursive:true});
for(const [name,engine] of [['chromium',chromium],['webkit',webkit]].filter(([n])=>!process.env.TARAYICI||process.env.TARAYICI===n)) {
  const {db}=await fixture();
  const browser=await engine.launch();
  let page;
  const disallowed=[];
  const failed=[];
  const posIstekleri=[];
  try {
    async function protect(context) {
      await context.route('**/*',async route=>{
        const u=new URL(route.request().url());
        for(const secret of ['4111111111111111','5555555555554444','05000000000']) assert.ok(!(route.request().postData()??'').includes(secret),'Tam kart bilgisi ağ isteğine girmemeli');
        // Otomatik giriş formu gerçek DenizPay'e çıkmaz: istek tarayıcıda yakalanıp yapay sayfayla yanıtlanır.
        if(u.hostname==='denizpay.bupilic.com.tr') {
          posIstekleri.push({method:route.request().method(),url:u.href,govde:route.request().postData()??''});
          return route.fulfill({status:200,contentType:'text/html; charset=utf-8',body:'<!doctype html><title>Yapay POS</title><p>yapay</p>'});
        }
        if(!['127.0.0.1','www.gstatic.com','apis.google.com'].includes(u.hostname)) {
          disallowed.push(`${u.hostname}${u.pathname}`);return route.abort();
        }
        await route.continue();
      });
    }
    const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true});
    await protect(context);
    page=await context.newPage(); page.setDefaultTimeout(20000);
    page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()?.errorText}));
    const errors=[];page.on('pageerror',e=>errors.push(e.stack));
    const button=name=>page.getByRole('button',{name,exact:true});
    async function write(name,value) {
      const f=page.getByRole('textbox',{name,exact:true}); await f.click();
      await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
      await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);
      await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
      assert.equal(await f.inputValue(),value);
    }
    // Kart formu alttan kayarak açılır; hareket bitmeden yapılan tıklama üstteki kutuya düşebilir.
    async function kartFormu() {
      await button('Kart ekle').click();
      await page.getByRole('textbox',{name:'Kart adı',exact:true}).waitFor();
      await page.waitForTimeout(700);
    }
    // WebKit'te Playwright'ın kaydırması bitmeden yapılan tıklama üstteki düğmeye düşebiliyor.
    async function bas(l) { await l.scrollIntoViewIfNeeded(); await page.waitForTimeout(500); await l.click(); }
    // Sayfadan ayrılmadan önce elle kilit: dinleyiciler kapanır. 0.7.3'ten beri kısa
    // sekme değişimi kilitlemediği için, açık dinleyiciyle sayfa kapanırken WebKit
    // iptal edilen veritabanı bağlantısını mesajsız bir hata olarak bildiriyor.
    async function ayril() {
      if(!page.url().startsWith('http://127.0.0.1:4197')) return;
      for(let i=0;i<3 && await page.getByRole('button',{name:'Kartlara dön',exact:true}).count()===0
        && await button('Ekranı kilitle').count()===0;i++) {await page.keyboard.press('Escape');await page.waitForTimeout(400);}
      if(await button('Ekranı kilitle').count()) {await button('Ekranı kilitle').click();await button('Kilidi aç').waitFor();}
    }
    async function open() {
      await ayril();
      await page.goto('http://127.0.0.1:4197');await page.locator('#acilis').waitFor({state:'detached'});
      const s=page.locator('flt-semantics-placeholder'); if(await s.count()) await s.evaluate(e=>e.click());
    }
    await open(); await button('Giriş yap').waitFor();
    await write('E-posta','admin@example.test');await write('Şifre',parola);await button('Giriş yap').click();
    await button('Yeni cari').click();await page.getByRole('textbox',{name:'Cari adı',exact:true}).waitFor();await page.waitForTimeout(700);
    await write('Cari adı','Örnek Telefon Carisi');
    assert.equal(await page.getByRole('textbox',{name:'Cari kodu',exact:true}).count(),0);
    await write('Vergi / TC kimlik numarası','0000000000');await button('Cariyi kaydet').click();
    await kartFormu();await write('Kart adı','Örnek İş Kartı');
    await write('Kart numarası','4111111111111111');
    // Yeni kartta numara açık yazı kutusudur. Kart alanı bildirimi (cc-number) erişilebilirlik kipinde
    // Flutter tarafından kapatıldığı için burada değil, test/kart_formu_test.dart içinde sınanır.
    assert.equal(await page.evaluate(()=>document.activeElement?.type),'text');
    await write('Kart üzerindeki ad (isteğe bağlı)','Örnek Yerel Kart Sahibi');await write('Ay','12');await write('Yıl','2030');
    await page.getByRole('checkbox',{name:'Kartı ve bu cari altında saklamayı kontrol ettim.'}).click();
    await button('Kartı kaydet').click();
    await page.getByRole('button',{name:/Örnek İş Kartı, son dört hane 1111/}).waitFor();
    await open();
    await page.getByRole('button',{name:/Örnek Telefon Carisi/}).click();
    await page.getByRole('button',{name:/Örnek İş Kartı, son dört hane 1111/}).waitFor();
    await bas(button('Bilgiler / düzenle'));await page.waitForTimeout(700);
    await page.getByRole('textbox',{name:'Kart numarası',exact:true}).waitFor();
    await button('Kart numarasını göster').click();
    await page.getByRole('textbox',{name:'Kart numarası',exact:true}).click();
    await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    assert.equal(await page.getByRole('textbox',{name:'Kart numarası',exact:true}).inputValue(),'4111111111111111');
    await write('İletişim telefonu (isteğe bağlı)','05000000000');
    await page.getByRole('checkbox',{name:'Kartı ve bu cari altında saklamayı kontrol ettim.'}).click();
    await button('Kartı kaydet').click();
    await kartFormu();await write('Kart adı','Örnek İkinci Kart');
    await write('Kart numarası','5555555555554444');await write('Ay','12');await write('Yıl','2030');
    await page.getByRole('checkbox',{name:'Kartı ve bu cari altında saklamayı kontrol ettim.'}).click();
    await button('Kartı kaydet').click();
    await page.getByRole('button',{name:/Örnek İkinci Kart, son dört hane 4444/}).waitFor();
    assert.equal(await page.getByRole('textbox',{name:/CVV/}).count(),0);
    // Otomatik giriş: seçim kontrolü bilgi göndermez; yalnız düğme tek POST yapar, kart bilgisi yoktur.
    await bas(page.getByRole('button',{name:/Örnek İş Kartı, son dört hane 1111/}));
    await button('Ödeme sitesine geç').click();
    await page.getByRole('checkbox',{name:'Cari ve seçili kartı kontrol ettim.'}).click();
    await button('Seçimi kontrol et').click();
    await page.getByRole('link',{name:'Boş giriş sayfasını aç',exact:true}).waitFor();
    assert.deepEqual(posIstekleri,[]);
    const [posSekmesi]=await Promise.all([context.waitForEvent('page'),button('DenizPay’e giriş yap').click()]);
    await posSekmesi.waitForLoadState();
    await page.getByText(/DenizPay yeni sekmede açıldı/).waitFor();
    assert.equal(posIstekleri.length,1);
    const [posIstek]=posIstekleri;
    assert.equal(posIstek.method,'POST');
    assert.equal(posIstek.url,'https://denizpay.bupilic.com.tr/login.aspx');
    assert.deepEqual(Object.fromEntries(new URLSearchParams(posIstek.govde)),
      {__VIEWSTATE:'',lvergino:'0000000000',lkullaniciadi:'0000000000',lsifre:'0000',btngiris:'Giriş Yap'});
    // Yeni sekme Sanal POS'a geri ulaşamaz; gönderimden sonra sayfada geçici form/değer kalmaz.
    assert.equal(await posSekmesi.evaluate(()=>window.opener),null);
    assert.equal(await page.evaluate(()=>[...document.querySelectorAll('form')].filter(f=>/denizpay/.test(f.action)).length),0);
    // Bu cihazda eklenen kart için "BUP Doldur" işi kurulur: yalnız kasa referansı, kart yok.
    const doldurmaIsi=JSON.parse(await page.evaluate(()=>localStorage.getItem('bup-doldurma-isi')));
    assert.deepEqual(Object.keys(doldurmaIsi).sort(),['kart','kimlikNo','son','uid','v']);
    assert.equal(doldurmaIsi.kimlikNo,'0000000000');
    assert.ok(doldurmaIsi.son>Date.now() && doldurmaIsi.son-Date.now()<=10*60*1000+5000);
    assert.ok(!/4111|5555|05000000000|Örnek Yerel Kart Sahibi/.test(JSON.stringify(doldurmaIsi)),'Bekleyen işte kart bilgisi olmamalı');
    await posSekmesi.close();
    await button('Kartlara dön').click();
    // Aynı hesap, ayrı tarayıcı profili: özet var; tam numara bu cihazda yok.
    const original=page;
    const otherDevice=await browser.newContext({viewport:{width:390,height:844}});
    await protect(otherDevice);page=await otherDevice.newPage();page.setDefaultTimeout(20000);
    page.on('pageerror',e=>errors.push(e.stack));
    page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()?.errorText}));
    await open();await write('E-posta','admin@example.test');await write('Şifre',parola);await button('Giriş yap').click();
    await page.getByRole('button',{name:/Örnek Telefon Carisi/}).click();
    await bas(page.getByRole('button',{name:'Bilgiler / düzenle',exact:true}).first());await page.waitForTimeout(700);
    await page.getByText(/Bu cihazda tam kart bilgisi yok/).waitFor();
    const emptyNumber=page.getByRole('textbox',{name:'Kart numarası',exact:true});
    await emptyNumber.click();await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    assert.equal(await emptyNumber.inputValue(),'');
    await ayril();await otherDevice.close();page=original;
    if(await button('Kilidi aç').count()) { await write('Şifre',parola);await button('Kilidi aç').click(); }
    await button('Ekranı kilitle').click();await button('Kilidi aç').waitFor();
    assert.equal(await page.evaluate(()=>localStorage.getItem('bup-doldurma-isi')),null,'Kilit bekleyen kart işini silmeli');
    await write('Şifre',parola);await button('Kilidi aç').click();
    await page.getByRole('button',{name:/Örnek Telefon Carisi/}).waitFor();
    await page.getByRole('tab',{name:'Çalışma alanı',exact:true}).click();
    await button('Kullanıcı yönetimi').click();await button('Hesap aç').click();
    await write('Ad soyad','Örnek Yeni Kullanıcı');await write('E-posta','yeni@example.test');await write('İlk giriş şifresi',parola);
    await button('Hesabı aç').click();
    await page.getByRole('group',{name:/Örnek Yeni Kullanıcı yeni@example.test/}).waitFor();
    assert.equal((await db.collection('kullanicilar').where('eposta','==','yeni@example.test').get()).size,1);
    await page.screenshot({path:`/tmp/bup-pos-qa-02/${name}-yonetim.png`});
    await button('Tüm cari atamaları').click();await page.getByText(/Örnek Telefon Carisi/).click();
    await page.getByText(/Örnek Yeni Kullanıcı/).click();await button('Ata').click();
    const cari=(await db.collection('cariler').where('kimlikNo','==','0000000000').get()).docs[0];
    await page.waitForFunction(()=>!document.body.textContent.includes('Atamayı onayla'));
    const kullanici=(await db.collection('kullanicilar').where('eposta','==','yeni@example.test').get()).docs[0];
    // Onay penceresi kapanmadan önce sorgulanırsa yazım henüz bitmemiş olabilir; en çok 10 sn beklenir.
    for(let i=0;i<40 && (await cari.ref.get()).data().sahipId!==kullanici.id;i++) await new Promise(r=>setTimeout(r,250));
    assert.equal((await cari.ref.get()).data().sahipId,kullanici.id);
    await ayril();await page.goto('about:blank');await context.clearCookies();
    // Yeni tarayıcı oturumu: yönetici oturumunu kullanmadan atanmış kaydı açar.
    const sales=await browser.newContext({viewport:{width:390,height:844}});
    await protect(sales);
    page=await sales.newPage();page.setDefaultTimeout(20000);page.on('pageerror',e=>errors.push(e.stack));
    page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()?.errorText}));
    await open();await write('E-posta','yeni@example.test');await write('Şifre',parola);await button('Giriş yap').click();
    await page.getByRole('button',{name:/Örnek Telefon Carisi/}).click();
    await page.getByRole('button',{name:/Örnek İş Kartı, son dört hane 1111/}).waitFor();
    await page.screenshot({path:`/tmp/bup-pos-qa-02/${name}-kartlar.png`});
    await kullanici.ref.update({aktif:false});
    await page.getByText(/Hesabının erişimi kapalı/).waitFor();
    assert.equal(await page.getByRole('button',{name:/Örnek İş Kartı/}).count(),0);
    // WebKit can report a cancelled streaming RPC using its latest polling URL,
    // while requestfailed retains the first URL. Require the same RPC session
    // and an independent browser cancellation, not merely a CORS-like message.
    const expectedAbort = error => {
      if(name!=='webkit') return false;
      const m=error.match(/^Fetch API cannot load (http:\/\/127\.0\.0\.1:8088\/google\.firestore\.v1\.Firestore\/(?:Listen|Write)\/channel\?\S+) due to access control checks\./);
      if(!m) return false;
      const rpc=new URL(m[1]);
      if(!rpc.searchParams.get('SID')) return false;
      return failed.some(f=>{
        if(f.error!=='Load request cancelled') return false;
        const cancelled=new URL(f.url);
        return rpc.origin===cancelled.origin && rpc.pathname===cancelled.pathname &&
          ['VER','database','RID','SID','CI','TYPE'].every(k=>rpc.searchParams.get(k)===cancelled.searchParams.get(k));
      });
    };
    const unexpected=errors.filter(e=>!expectedAbort(e));
    if(unexpected.length) await writeFile(`/tmp/bup-pos-qa-02/${name}-ag.json`,JSON.stringify({errors,failed},null,2));
    assert.deepEqual(unexpected,[],'Beklenmeyen tarayıcı hatası olmamalı');
    assert.deepEqual(disallowed,[],'SDK ve yerel emülatör dışında istek olmamalı');
    console.log(`PASS ${name}: giriş, kalıcı cari/kart, otomatik DenizPay giriş formu, kilit doğrulaması, hesap açma, atama, yetki iptali`);
    if(errors.length) console.log(`  Tarayıcının ayrıca iptal olarak doğruladığı yerel RPC oturumu: ${errors.length}`);
  } catch(e) {
    console.error('Engellenen harici istekler:',disallowed);
    console.error('Başarısız ağ sonuçları:',failed.map(r=>({path:new URL(r.url).pathname,error:r.error})));
    if(page) { console.error(await page.locator('body').ariaSnapshot());await page.screenshot({path:`/tmp/bup-pos-qa-02/${name}-hata.png`}); }
    throw e;
  } finally {await browser.close();}
}
