import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { chromium, webkit } from 'playwright';

// Yalnız yeni projenin halka açık giriş ekranı. Giriş/ödeme/veri yazma yoktur.
const origin='https://bup-sanal-pos-izmir.web.app';
const local=await readFile(new URL('../../build/canli/main.dart.js',import.meta.url));
const hash=data=>createHash('sha256').update(data).digest('hex');
let published;
// Hosting release bildirimi ile tüm edge'lerin yeni sürümü sunması arasında
// kısa gecikme olabilir. Gerçek bootstrap ile aynı sürümlü adresi doğrula.
for(let attempt=0;attempt<6;attempt++) {
  const remote=await fetch(`${origin}/main.dart.js?v=${hash(local).slice(0,16)}`,
    {headers:{'Cache-Control':'no-cache'}});
  assert.equal(remote.status,200);
  published=hash(new Uint8Array(await remote.arrayBuffer()));
  if(published===hash(local)) break;
  await new Promise(resolve=>setTimeout(resolve,1500));
}
assert.equal(published,hash(local),'Yayımlanan kod derlemeyle eşleşmeli');
const response=await fetch(origin);
assert.equal(response.status,200);
assert.equal(response.headers.get('x-content-type-options'),'nosniff');
assert.equal(response.headers.get('x-frame-options'),'DENY');
const csp=response.headers.get('content-security-policy');
assert.ok(csp.includes("frame-ancestors 'none'"));
// Form gönderimi yalnız sabit DenizPay kökenine (otomatik giriş); başka hedef yok.
assert.equal(csp.split(';').map(s=>s.trim()).find(s=>s.startsWith('form-action')),'form-action https://denizpay.bupilic.com.tr');
assert.ok(!csp.split('script-src')[1].split(';')[0].includes("'unsafe-inline'"));
// Ana ekran simgesi tarayıcı içinde açılır (kullanıcı kararı): iPhone'da ayrı depolu uygulama
// olursa "BUP Doldur" bekleyen kartı göremez.
const anaSayfa=await (await fetch(origin)).text();
assert.ok(!/<meta[^>]+web-app-capable/.test(anaSayfa),'Ana ekran ayrı uygulama olarak açılmamalı');
assert.equal((await (await fetch(`${origin}/manifest.json`)).json()).display,'browser');
for(const collection of ['cariler','kullanicilar']) {
  const denied=await fetch(`https://firestore.googleapis.com/v1/projects/bup-sanal-pos-izmir/databases/(default)/documents/${collection}/erisim-siniri-denemesi`);
  assert.equal(denied.status,403,'Oturumsuz veri okuma sunucuda reddedilmeli');
  assert.equal((await denied.json()).error.status,'PERMISSION_DENIED');
}

for(const [name,engine] of [['chromium',chromium],['webkit',webkit]]) {
  const browser=await engine.launch();
  try {
    const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
    const errors=[],blocked=[],badResponses=[];
    page.on('pageerror',e=>errors.push(String(e)));
    page.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
    page.on('response',r=>{if(r.status()>=400) badResponses.push(`${r.status()} ${new URL(r.url()).pathname}`);});
    await page.route('**/*',async route=>{
      const u=new URL(route.request().url());
      if(!['bup-sanal-pos-izmir.web.app','bup-sanal-pos-izmir.firebaseapp.com',
        'www.gstatic.com','apis.google.com','identitytoolkit.googleapis.com','securetoken.googleapis.com'].includes(u.hostname)) {
        blocked.push(`${u.hostname}${u.pathname}`);return route.abort();
      }
      return route.continue();
    });
    await page.goto(origin);
    await page.locator('#acilis').waitFor({state:'detached',timeout:30000});
    const semantics=page.locator('flt-semantics-placeholder');
    if(await semantics.count()) await semantics.evaluate(e=>e.click());
    await page.getByRole('button',{name:'Giriş yap',exact:true}).waitFor();
    assert.equal(await page.getByRole('textbox',{name:'E-posta',exact:true}).count(),1);
    assert.equal(await page.getByRole('textbox',{name:'Şifre',exact:true}).count(),1);
    assert.equal(await page.getByRole('button',{name:'Yeni cari',exact:true}).count(),0);
    await page.screenshot({path:`/tmp/bup-pos-qa-02/${name}-canli-giris.png`});
    assert.deepEqual(blocked,[]);
    assert.deepEqual(badResponses,[]);
    assert.deepEqual(errors,[]);
    console.log(`PASS ${name}: HTTPS giriş, Firebase başlangıcı, yerel varlıklar, yayın başlıkları`);
  } finally {await browser.close();}
}
console.log(`PASS yayın kod özeti: ${hash(local).slice(0,16)}`);
