// Yalnız cihazda. Bu modül ağ isteği yapmaz, anahtar veya kartı dışa aktarmaz.
const DB = 'bup-pos-cihaz-kasasi';
const enc = new TextEncoder(), dec = new TextDecoder();
let database;
const fail = () => { throw new Error('cihaz_kasasi'); };
const req = request => new Promise((resolve,reject)=>{
  request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(new Error('cihaz_kasasi'));
});
const done = tx => new Promise((resolve,reject)=>{
  tx.oncomplete=()=>resolve();tx.onabort=tx.onerror=()=>reject(new Error('cihaz_kasasi'));
});
function db() {
  if(!globalThis.isSecureContext||!globalThis.crypto?.subtle||!globalThis.indexedDB) fail();
  return database??=new Promise((resolve,reject)=>{
    const r=indexedDB.open(DB,1);
    r.onupgradeneeded=()=>{
      r.result.createObjectStore('anahtarlar');
      for(const name of ['kartlar','taslaklar']) {
        const s=r.result.createObjectStore(name,{keyPath:'id'});
        s.createIndex('bag',['uid','cariId','kartId']);
        s.createIndex('cari',['uid','cariId']);s.createIndex('kullanici','uid');
      }
    };
    r.onsuccess=()=>{
      r.result.onversionchange=()=>{r.result.close();database=undefined;};resolve(r.result);
    };
    r.onerror=r.onblocked=()=>{database=undefined;reject(new Error('cihaz_kasasi'));};
  });
}
function scope(uid,meta) {
  for(const value of [uid,meta.cariId,meta.id]) {
    if(typeof value!=='string'||value.length<1||value.length>128||/[\x00-\x1f]/.test(value)) fail();
  }
  if(!/^[0-9]{4}$/.test(meta.sonDort)||!Number.isInteger(meta.ay)||meta.ay<1||meta.ay>12||
    !Number.isInteger(meta.yil)||meta.yil<2000||meta.yil>2199) fail();
}
const primary = (uid,meta)=>JSON.stringify([uid,meta.cariId,meta.id]);
const aad = (uid,meta,stamp)=>enc.encode(JSON.stringify(['bup-pos-kart',1,uid,meta.cariId,meta.id,meta.sonDort,meta.ay,meta.yil,stamp]));
function payload(text,meta) {
  if(typeof text!=='string'||text.length>1000) fail();
  const p=JSON.parse(text);
  if(Object.keys(p).sort().join(',')!=='numara,sahibi,telefon'||
    !/^[0-9]{12,19}$/.test(p.numara)||p.numara.slice(-4)!==meta.sonDort||
    typeof p.sahibi!=='string'||p.sahibi.length>120||/[\x00-\x1f\x7f]/.test(p.sahibi)||
    typeof p.telefon!=='string'||!(p.telefon===''||/^\+905[0-9]{9}$/.test(p.telefon))) fail();
  let total=0,twice=false;
  for(let i=p.numara.length-1;i>=0;i--,twice=!twice) {
    let n=Number(p.numara[i]);if(twice){n*=2;if(n>9)n-=9;}total+=n;
  }
  if(total%10!==0||/^0+$/.test(p.numara)) fail();
  return p;
}
async function key(uid,create=false) {
  const d=await db();
  const old=await req(d.transaction('anahtarlar').objectStore('anahtarlar').get(uid));
  if(old) {
    if(old.type!=='secret'||old.extractable||old.algorithm?.name!=='AES-GCM'||old.algorithm.length!==256) fail();
    return old;
  }
  if(!create) fail();
  for(const name of ['kartlar','taslaklar']) {
    if(await req(d.transaction(name).objectStore(name).index('kullanici').count(uid))) fail();
  }
  const generated=await crypto.subtle.generateKey({name:'AES-GCM',length:256},false,['encrypt','decrypt']);
  // Aynı hesaba ait iki sekme ilk anahtarı eşzamanlı ürettiğinde yalnız biri kazanır.
  const tx=d.transaction('anahtarlar','readwrite'),finish=done(tx),s=tx.objectStore('anahtarlar');
  let chosen;
  const r=s.get(uid);
  r.onsuccess=()=>{chosen=r.result??generated;if(!r.result)s.put(chosen,uid);};
  await finish;return chosen;
}
async function prepare(uid,metaJson,text) {
  const meta=JSON.parse(metaJson);scope(uid,meta);payload(text,meta);
  const d=await db(),k=await key(uid,true),stamp=crypto.randomUUID();
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const plain=enc.encode(text);
  let cipher;
  try {cipher=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:aad(uid,meta,stamp),tagLength:128},k,plain);}
  finally {plain.fill(0);}
  const tx=d.transaction('taslaklar','readwrite'),finish=done(tx);
  tx.objectStore('taslaklar').add({id:stamp,uid,cariId:meta.cariId,kartId:meta.id,
    aktifId:primary(uid,meta),meta:{sonDort:meta.sonDort,ay:meta.ay,yil:meta.yil},iv,cipher,version:1});
  await finish;return stamp;
}
async function commit(uid,stamp) {
  const d=await db(),tx=d.transaction(['kartlar','taslaklar'],'readwrite'),finish=done(tx);
  const s=tx.objectStore('taslaklar'),r=s.get(stamp);
  r.onsuccess=()=>{
    const entry=r.result;
    if(!entry||entry.uid!==uid){tx.abort();return;}
    tx.objectStore('kartlar').put({...entry,id:entry.aktifId,stamp:entry.id});s.delete(stamp);
  };
  await finish;
}
async function read(uid,metaJson) {
  const meta=JSON.parse(metaJson);scope(uid,meta);
  if(!meta.cihazKayitId) return null;
  const d=await db();
  let pending=false;
  let entry=await req(d.transaction('kartlar').objectStore('kartlar').get(primary(uid,meta)));
  if(!entry||entry.stamp!==meta.cihazKayitId) {
    const staged=await req(d.transaction('taslaklar').objectStore('taslaklar').get(meta.cihazKayitId));
    if(!staged) return null;
    if(staged.uid!==uid||staged.aktifId!==primary(uid,meta)) fail();
    // Çağıran uygulama bu referansı önce güncel yetkili sunucu kaydında doğrular.
    pending=true;entry={...staged,stamp:staged.id};
  }
  if(entry.version!==1||entry.uid!==uid||entry.cariId!==meta.cariId||entry.kartId!==meta.id) fail();
  const plain=new Uint8Array(await crypto.subtle.decrypt({name:'AES-GCM',iv:entry.iv,
    additionalData:aad(uid,meta,entry.stamp),tagLength:128},await key(uid),entry.cipher));
  try {const text=dec.decode(plain);payload(text,meta);if(pending)await commit(uid,meta.cihazKayitId);return text;}
  finally {plain.fill(0);}
}
async function remove(uid,cariId,kartId) {
  scope(uid,{cariId,id:kartId??'tum',sonDort:'0000',ay:1,yil:2000});
  const d=await db(),tx=d.transaction(['kartlar','taslaklar'],'readwrite'),finish=done(tx);
  for(const name of ['kartlar','taslaklar']) {
    const s=tx.objectStore(name),index=s.index(kartId?'bag':'cari');
    const r=index.openKeyCursor(IDBKeyRange.only(kartId?[uid,cariId,kartId]:[uid,cariId]));
    r.onsuccess=()=>{const c=r.result;if(c){s.delete(c.primaryKey);c.continue();}};
  }
  await finish;
}
// Dışarıya yalnız sonuç/sabit hata kodu çıkar; kart ve tarayıcı istisnası loglanmaz.
const safe=fn=>async(...args)=>{
  try{return JSON.stringify({ok:true,value:await fn(...args)});}
  catch{return JSON.stringify({ok:false});}
};
globalThis.bupKartKasasi=Object.freeze({hazirla:safe(prepare),tamamla:safe(commit),oku:safe(read),sil:safe(remove)});
