import assert from 'node:assert/strict';
import { chromium,webkit } from 'playwright';
// Yalnız yapay kart, yerel paket; hiçbir harici ağ isteğine izin verilmez.
const origin='http://127.0.0.1:4195';
for(const [name,engine] of [['chromium',chromium],['webkit',webkit]]) {
  const browser=await engine.launch();
  try {
    const context=await browser.newContext();
    const unexpected=[];
    await context.route('**/*',route=>{
      if(new URL(route.request().url()).origin!==origin) {unexpected.push('harici');return route.abort();}
      return route.continue();
    });
    const page=await context.newPage();
    async function open(){await page.goto(origin);await page.evaluate(()=>import('/kart_kasasi.js'));}
    const call=(method,...args)=>page.evaluate(async({method,args})=>
      JSON.parse(await globalThis.bupKartKasasi[method](...args)),{method,args});
    await open();
    const uid='yapay-hesap',meta={id:'yapay-kart',cariId:'yapay-cari',sonDort:'1111',ay:12,yil:2030};
    const plain={numara:'4111111111111111',sahibi:'Örnek Kart Sahibi',telefon:''};
    let r=await call('hazirla',uid,JSON.stringify(meta),JSON.stringify(plain));assert.equal(r.ok,true);
    const stamp=r.value,withRef={...meta,cihazKayitId:stamp};
    // Şifreli taslak dışında kalıcı numara/kişi/telefon alanı yoktur; anahtar dışa aktarılamaz.
    const storage=await page.evaluate(async uid=>{
      const d=await new Promise((r,j)=>{const q=indexedDB.open('bup-pos-cihaz-kasasi',1);q.onsuccess=()=>r(q.result);q.onerror=j;});
      const get=(store,key)=>new Promise((r,j)=>{const q=d.transaction(store).objectStore(store)[key===undefined?'getAll':'get'](key);q.onsuccess=()=>r(q.result);q.onerror=j;});
      const entries=await get('taslaklar'),k=await get('anahtarlar',uid);
      let exported=false;try{await crypto.subtle.exportKey('raw',k);exported=true;}catch{}
      return {extractable:k.extractable,algorithm:k.algorithm,exported,
        entries:entries.map(e=>({keys:Object.keys(e),text:new TextDecoder().decode(e.cipher)})),
        local:JSON.stringify(localStorage),session:JSON.stringify(sessionStorage)};
    },uid);
    assert.equal(storage.extractable,false);assert.equal(storage.exported,false);
    assert.equal(storage.algorithm.name,'AES-GCM');assert.equal(storage.algorithm.length,256);
    assert.ok(!JSON.stringify(storage).includes(plain.numara));
    assert.ok(!storage.entries[0].keys.some(k=>['numara','sahibi','telefon','cvv'].includes(k)));
    // Sunucu onayı sonrası son yerel adım yarıda kalırsa referansla kurtarılır.
    r=await call('oku',uid,JSON.stringify(withRef));assert.deepEqual(JSON.parse(r.value),plain);
    await open();r=await call('oku',uid,JSON.stringify(withRef));assert.deepEqual(JSON.parse(r.value),plain);
    assert.equal((await call('oku','baska-hesap',JSON.stringify(withRef))).value,null);
    assert.equal((await call('oku',uid,JSON.stringify({...withRef,ay:11}))).ok,false);
    assert.equal((await call('oku',uid,JSON.stringify({...withRef,cihazKayitId:'yok'}))).value,null);
    for(const bad of [{...plain,cvv:'yapay'}, {...plain,numara:'4111111111111112'}]) {
      assert.equal((await call('hazirla',uid,JSON.stringify(meta),JSON.stringify(bad))).ok,false);
    }
    // İlk açılışta yarışan iki sekmenin/işlemin anahtarı aynı kalır.
    const metas=[{...meta,id:'es-1'},{...meta,id:'es-2'}];
    const stages=await Promise.all(metas.map(m=>call('hazirla','yeni-hesap',JSON.stringify(m),JSON.stringify(plain))));
    for(let i=0;i<stages.length;i++){
      assert.equal(stages[i].ok,true);await call('tamamla','yeni-hesap',stages[i].value);
      assert.equal((await call('oku','yeni-hesap',JSON.stringify({...metas[i],cihazKayitId:stages[i].value}))).ok,true);
    }
    // Şifreli veri bozulunca sessiz sıfırlama yapılmaz.
    await page.evaluate(async uid=>{
      const d=await new Promise(r=>{const q=indexedDB.open('bup-pos-cihaz-kasasi',1);q.onsuccess=()=>r(q.result);});
      await new Promise((resolve,reject)=>{
        const tx=d.transaction('kartlar','readwrite'),s=tx.objectStore('kartlar');
        tx.oncomplete=resolve;tx.onerror=reject;
        const q=s.getAll();q.onsuccess=()=>{const e=q.result.find(x=>x.uid===uid);
          const b=new Uint8Array(e.cipher);b[0]^=1;e.cipher=b.buffer;s.put(e);};
      });
    },uid);
    assert.equal((await call('oku',uid,JSON.stringify(withRef))).ok,false);
    assert.equal((await call('sil',uid,meta.cariId,meta.id)).ok,true);
    assert.equal((await call('oku',uid,JSON.stringify(withRef))).value,null);
    assert.equal((await call('oku','yeni-hesap',JSON.stringify({...metas[0],cihazKayitId:stages[0].value}))).ok,true);
    assert.equal((await call('sil','yeni-hesap',meta.cariId,null)).ok,true);
    assert.equal((await call('oku','yeni-hesap',JSON.stringify({...metas[0],cihazKayitId:stages[0].value}))).value,null);
    assert.deepEqual(unexpected,[]);
    await context.close();
    const fresh=await browser.newContext(),other=await fresh.newPage();
    await other.goto(origin);await other.evaluate(()=>import('/kart_kasasi.js'));
    assert.equal((await other.evaluate(async({uid,withRef})=>
      JSON.parse(await globalThis.bupKartKasasi.oku(uid,JSON.stringify(withRef))),{uid,withRef})).value,null);
    await fresh.close();
    console.log(`PASS ${name}: AES-GCM, anahtar yarışı, yenileme, taslak kurtarma, hesap/cihaz ayrımı, değişiklik/bozulma reddi, silme`);
  } finally {await browser.close();}
}
