import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, writeBatch, serverTimestamp } from 'firebase/firestore';
let env;
const uid = 'satici-a', other = 'satici-b';
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-bup-pos', firestore: {
    host: '127.0.0.1', port: 8088, rules: await readFile('../../firestore.rules', 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
const dbFor = who => who ? env.authenticatedContext(who).firestore() : env.unauthenticatedContext().firestore();
const record = (owner = uid, code = 'OR-001') => ({sahipId: owner, ad:'Örnek Market', kod:code,
  kodAnahtari:code.toUpperCase(), yildizli:false, surum:1, kartlar:[], silindi:false,
  sonKart:null, kimlikNo:'', olusturma:serverTimestamp(), guncelleme:serverTimestamp()});
function audit(b, db, id, revision, actor, action) {
  b.set(doc(db, 'denetim', `${id}_${revision}`), {kullaniciId:actor,cariId:id,surum:revision,eylem:action,zaman:serverTimestamp()});
}
function create(db, id, owner = uid, code = 'OR-001', patch = {}) {
  const b = writeBatch(db), data = {...record(owner,code),...patch};
  b.set(doc(db,'cariler',id),data);
  b.set(doc(db,'cariKodlari',`${owner}_${code.toUpperCase()}`),{sahipId:owner,kod:code.toUpperCase(),cariId:id});
  audit(b,db,id,1,owner,'ekle'); return b.commit();
}
async function change(db, id, actor, patch, {codeFrom,codeTo,ownerFrom=uid,ownerTo=uid} = {}) {
  const b = writeBatch(db), revision = patch.surum ?? 2;
  b.update(doc(db,'cariler',id), {...patch,...('kartlar' in patch ? {sonKart:patch.kartlar.at(-1)??null} : {}),guncelleme:serverTimestamp()});
  if(codeFrom) b.delete(doc(db,'cariKodlari',`${ownerFrom}_${codeFrom}`));
  if(codeTo) b.set(doc(db,'cariKodlari',`${ownerTo}_${codeTo}`),{sahipId:ownerTo,kod:codeTo,cariId:id});
  audit(b,db,id,revision,actor,patch.silindi?'sil':'kaydet'); return b.commit();
}
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db=ctx.firestore(), b=writeBatch(db);
    for (const who of [uid, other, 'admin', 'pasif']) b.set(doc(db,'kullanicilar',who),{
      ad:'Örnek Kullanıcı',eposta:`${who}@example.test`,yonetici:who==='admin',aktif:who!=='pasif',
      olusturma:serverTimestamp(),guncelleme:serverTimestamp()});
    b.set(doc(db,'cariler','yabanci'),record(other));
    b.set(doc(db,'cariKodlari',`${other}_OR-001`),{sahipId:other,kod:'OR-001',cariId:'yabanci'});
    await b.commit();
  });
});
test('Anonim ve erişim profili olmayan hesap kaydı okuyamaz',async()=>{
  for(const who of [null,'izinsiz','pasif']) await assertFails(getDoc(doc(dbFor(who),'cariler','yabanci')));
});
test('Başka kullanıcı doğrudan kimlikle okuyamaz',async()=>{
  await assertFails(getDoc(doc(dbFor(uid),'cariler','yabanci')));
});
test('Kullanıcı yalnız atanmış aktif carileri sorgulayabilir',async()=>{
  const db=dbFor(uid); await assertSucceeds(create(db,'kendi'));
  await assertSucceeds(getDocs(query(collection(db,'cariler'),where('sahipId','==',uid),where('silindi','==',false))));
  await assertFails(getDocs(collection(db,'cariler')));
});
test('Cari ve kod rezervasyonu denetim kaydıyla atomik oluşturulur',async()=>{
  const db=dbFor(uid); await assertSucceeds(create(db,'kendi'));
  await assertFails(setDoc(doc(db,'cariler','izsiz'),record(uid,'OR-002')));
});
test('Aynı kullanıcıdaki cari kodu ikinci kayıtla ele geçirilemez',async()=>{
  const db=dbFor(uid); await create(db,'ilk'); await assertFails(create(db,'ikinci'));
});
test('Kod rezervasyonu tek başına silinemez',async()=>{
  const db=dbFor(uid); await create(db,'ilk');const b=writeBatch(db);
  b.delete(doc(db,'cariKodlari',`${uid}_OR-001`));await assertFails(b.commit());
});
test('Kullanıcı kendisini yönetici yapamaz',async()=>{
  await assertFails(updateDoc(doc(dbFor(uid),'kullanicilar',uid),{yonetici:true}));
});
test('Yönetici kendi erişimini veya başka yöneticiyi istemciden değiştiremez',async()=>{
  await assertFails(updateDoc(doc(dbFor('admin'),'kullanicilar','admin'),{aktif:false,guncelleme:serverTimestamp()}));
});
test('Satıcı cari atamasını değiştiremez',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertFails(change(db,'kendi',uid,{sahipId:other,surum:2},{codeFrom:'OR-001',codeTo:'OR-002',ownerTo:other}));
});
test('Yönetici cariyi atomik atar; önceki kullanıcı erişemez',async()=>{
  const db=dbFor(uid);await create(db,'kendi','satici-a','OR-002');
  await assertSucceeds(change(dbFor('admin'),'kendi','admin',{sahipId:other,surum:2},{codeFrom:'OR-002',codeTo:'OR-002',ownerTo:other}));
  await assertFails(getDoc(doc(db,'cariler','kendi')));
  await assertSucceeds(getDoc(doc(dbFor(other),'cariler','kendi')));
});
test('Pasif hesaba atama yapılamaz',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertFails(change(dbFor('admin'),'kendi','admin',{sahipId:'pasif',surum:2},{codeFrom:'OR-001',codeTo:'OR-001',ownerTo:'pasif'}));
});
test('Eski sürüm ve izsiz güncelleme reddedilir',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertFails(change(db,'kendi',uid,{ad:'Eski değişiklik',surum:1}));
  await assertFails(updateDoc(doc(db,'cariler','kendi'),{ad:'İzsiz değişiklik',surum:2,guncelleme:serverTimestamp()}));
});
test('Ham kart numarası veya CVV eklenemez',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  const k={id:'ornek',ad:'Örnek Kart',sonDort:'0010',ay:12,yil:2030,cihazKayitId:'yapay-kayit'};
  for(const extra of [{pan:'yapay-hassas-alan'},{cvv:'yapay-hassas-alan'}])
    await assertFails(change(db,'kendi',uid,{surum:2,kartlar:[{...k,...extra}]}));
  await assertFails(change(db,'kendi',uid,{surum:2,kartlar:[{...k,ad:'4111 1111 1111 1111'}]}));
  await assertSucceeds(change(db,'kendi',uid,{surum:2,kartlar:[k]}));
});
test('Kart tarihi ve on kart sınırı sunucuda uygulanır',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  const k={id:'ornek',ad:'Örnek Kart',sonDort:'0010',ay:13,yil:2030,cihazKayitId:'yapay-kayit'};
  await assertFails(change(db,'kendi',uid,{surum:2,kartlar:[k]}));
  await assertFails(change(db,'kendi',uid,{surum:2,kartlar:Array(11).fill({...k,ay:12})}));
  const liste=[];
  for(let i=0;i<10;i++) {
    liste.push({...k,id:`kart-${i}`,ay:12});
    await assertSucceeds(change(db,'kendi',uid,{surum:i+2,kartlar:[...liste]}));
  }
  await assertFails(change(db,'kendi',uid,{surum:12,kartlar:[...liste,{...k,id:'sinir-ustu',ay:12}]}));
});
test('Silme kartları bırakır, kodu serbest bırakır ve eski erişimi kapatır',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertSucceeds(change(db,'kendi',uid,{silindi:true,surum:2,kartlar:[]},{codeFrom:'OR-001'}));
  await assertFails(getDoc(doc(db,'cariler','kendi')));
  await assertSucceeds(create(db,'yeni'));
});
test('Erişimi kapatılmış kullanıcının geçerli tokenı da veri okuyamaz',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertSucceeds(updateDoc(doc(dbFor('admin'),'kullanicilar',uid),{aktif:false,guncelleme:serverTimestamp()}));
  await assertFails(getDoc(doc(db,'cariler','kendi')));
});
test('Denetim kaydı sonradan değiştirilemez',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  await assertFails(updateDoc(doc(dbFor('admin'),'denetim','kendi_1'),{eylem:'sil'}));
});

test('Yerel kayıt referansı kabul edilir; tam numara, kart sahibi ve telefon buluta yazılamaz',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  const k={id:'ornek',ad:'Örnek Kart',sonDort:'0010',ay:12,yil:2030,cihazKayitId:'yapay-kayit'};
  for(const extra of [{numara:'yapay'},{sahibi:'Yapay Sahip'},{telefon:'yapay'},{cvv:'yapay'}])
    await assertFails(change(db,'kendi',uid,{surum:2,kartlar:[{...k,...extra}]}));
  await assertFails(change(db,'kendi',uid,{surum:2,kartlar:[{...k,ad:'4111 1111 1111 1111'}]}));
  await assertSucceeds(change(db,'kendi',uid,{surum:2,kartlar:[k]}));
});

test('Eski istemci yerel kart referansını düşüremez; eski özetler okunur ve korunur',async()=>{
  const db=dbFor(uid);await create(db,'kendi');
  const old={id:'ornek',ad:'Örnek Kart',sonDort:'0010',ay:12,yil:2030};
  await env.withSecurityRulesDisabled(async ctx=>{
    await updateDoc(doc(ctx.firestore(),'cariler','kendi'),{kartlar:[old],sonKart:old});
  });
  await assertSucceeds(getDoc(doc(db,'cariler','kendi')));
  await assertSucceeds(change(db,'kendi',uid,{ad:'Örnek Yeni Ad',surum:2,sonKart:null}));
  const current={...old,cihazKayitId:'yapay-kayit'};
  await assertSucceeds(change(db,'kendi',uid,{surum:3,kartlar:[current]}));
  await assertFails(change(db,'kendi',uid,{surum:4,kartlar:[old]}));
});
