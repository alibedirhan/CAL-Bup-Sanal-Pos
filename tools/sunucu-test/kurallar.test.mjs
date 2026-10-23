import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';
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

// 0.9.0 tahsilat kayıtları (0.10.0 eşleşme izi): yalnız eklenir, sunucu saatiyle; cari erişimi ve VKN eşleşmeli.
const KIMLIK='0000000001';
const tahsilatCari=async()=>{
  await env.withSecurityRulesDisabled(async ctx=>{
    await setDoc(doc(ctx.firestore(),'cariler','kendi'),{...record(uid,KIMLIK),kimlikNo:KIMLIK});
  });
};
const girisVerisi=(patch={})=>({kullaniciId:uid,kullaniciAd:'Örnek Kullanıcı',cariId:'kendi',cariAd:'Örnek Market',
  kimlikNo:KIMLIK,kartSonDort:'1111',zaman:serverTimestamp(),...patch});
const islemVerisi=(no='VP10000000000000001',patch={})=>({...girisVerisi(),girisId:'A'.repeat(20),sonuc:'basarili',
  aciklama:'Ödeme Başarıyla Gerçekleştirildi',posSiparisNo:no,uyeSiparisNo:'600001',tutarMetni:'4500',tutarKurus:450000,
  kaynak:'yer_imi',eslesme:'tek_giris',okunma:Timestamp.fromMillis(Date.now()-60000),...patch});
test('Giriş ve işlem kaydı kendi carisi için eklenir, sonra değiştirilemez/silinemez',async()=>{
  await tahsilatCari();const db=dbFor(uid);
  await assertSucceeds(setDoc(doc(db,'posGirisleri','A'.repeat(20)),girisVerisi()));
  const ref=doc(db,'posIslemleri','VP10000000000000001');
  await assertSucceeds(getDoc(ref)); // olmayan kayıt sorgulanabilir
  await assertSucceeds(setDoc(ref,islemVerisi()));
  await assertSucceeds(getDoc(ref));
  await assertFails(setDoc(ref,islemVerisi(undefined,{tutarMetni:'1',tutarKurus:100}))); // ikinci yazım
  await assertFails(updateDoc(ref,{tutarMetni:'1'}));
  const {deleteDoc}=await import('firebase/firestore');
  await assertFails(deleteDoc(ref));
  await assertFails(updateDoc(doc(db,'posGirisleri','A'.repeat(20)),{cariAd:'Başka'}));
  await assertFails(deleteDoc(doc(db,'posGirisleri','A'.repeat(20))));
  // Hata sonucu, okunamayan tutar ve kartsız/girişsiz elle kayıt da kabul edilir.
  await assertSucceeds(setDoc(doc(db,'posIslemleri','VP0002-h'),islemVerisi('VP0002',{sonuc:'hata',aciklama:'3D Şifresi Yanlış.',
    uyeSiparisNo:'',tutarMetni:'4,500.00',tutarKurus:null,kartSonDort:'',girisId:'',kaynak:'elle',eslesme:'elle',okunma:null})));
});
test('Başarısız deneme "-h" kimlikle ayrı yazılır; aynı numaralı başarılı ödeme engellenmez (0.10.1)',async()=>{
  await tahsilatCari();const db=dbFor(uid);
  const hata={sonuc:'hata',aciklama:'İşlem onaylanmadı.',uyeSiparisNo:''};
  const no='VP10000000000000090';
  await assertFails(setDoc(doc(db,'posIslemleri',no),islemVerisi(no,hata))); // başarısız "-h" eksiz yazılamaz
  await assertFails(setDoc(doc(db,'posIslemleri',`${no}-h`),islemVerisi(no))); // başarılı "-h" ile yazılamaz
  await assertSucceeds(setDoc(doc(db,'posIslemleri',`${no}-h`),islemVerisi(no,hata)));
  await assertSucceeds(setDoc(doc(db,'posIslemleri',no),islemVerisi(no))); // sonra gelen başarılı ödeme
  await assertFails(setDoc(doc(db,'posIslemleri',`${no}-h`),islemVerisi(no,hata))); // aynı sonuç ikinci kez
  await assertFails(setDoc(doc(db,'posIslemleri',no),islemVerisi(no,{tutarMetni:'1',tutarKurus:100})));
  await assertFails(setDoc(doc(db,'posIslemleri','VP91-H'),islemVerisi('VP91',hata))); // büyük harf ek yok
  await assertFails(setDoc(doc(db,'posIslemleri','VP92-h-h'),islemVerisi('VP92-h',hata))); // numara küçük harf olamaz
  await assertSucceeds(getDoc(doc(db,'posIslemleri',`${no}-h`)));
});
test('Cari eşleşmesi ve okunma anı (0.10.0) kurala uymalı',async()=>{
  await tahsilatCari();const db=dbFor(uid);
  const yaz=(no,patch)=>setDoc(doc(db,'posIslemleri',no),islemVerisi(no,patch));
  for (const [i,e] of ['sonuc_ekrani','kart_sayfasi','tek_giris','secim'].entries()) await assertSucceeds(yaz(`VP006${i}`,{eslesme:e}));
  await assertSucceeds(yaz('VP0070',{okunma:Timestamp.fromMillis(Date.now()-30*86400000)})); // 30 gün bekleyen sonuç
  await assertSucceeds(yaz('VP0071',{eslesme:'son_giris'})); // 0.9.0'dan telefonda bekleyen sonuç
  await assertFails(yaz('VP0072',{eslesme:'elle'})); // yer imi kaydı elle eşleşme diyemez
  await assertFails(yaz('VP0073',{kaynak:'elle'})); // elle kayıt eşleşme taşımaz
  await assertFails(yaz('VP0074',{kaynak:'elle',eslesme:'elle'})); // elle kayıtta okunma yok
  await assertFails(yaz('VP0075',{okunma:null}));
  await assertSucceeds(yaz('VP0081',{okunma:Timestamp.fromMillis(Date.now()+3600000)})); // telefon saati ileri
  await assertFails(yaz('VP0076',{okunma:Timestamp.fromMillis(Date.now()+2*86400000)}));
  await assertFails(yaz('VP0077',{okunma:Timestamp.fromMillis(Date.now()-32*86400000)}));
  await assertFails(yaz('VP0078',{okunma:Date.now()}));
  await assertFails(yaz('VP0079',{eslesme:'bilinmiyor'}));
  const {eslesme,...eksik}=islemVerisi('VP0080');
  await assertFails(setDoc(doc(db,'posIslemleri','VP0080'),eksik));
});
test('Yanlış VKN, başka kullanıcının carisi, başkası adına ve istemci saatiyle kayıt reddedilir',async()=>{
  await tahsilatCari();const db=dbFor(uid);
  const yaz=(no,patch)=>setDoc(doc(db,'posIslemleri',no),islemVerisi(no,patch));
  await assertSucceeds(yaz('VP0009',{}));
  await assertFails(yaz('VP10',{kimlikNo:'0000000009'}));
  await assertFails(yaz('VP11',{cariId:'yabanci'}));
  await assertFails(yaz('VP12',{kullaniciId:other}));
  await assertFails(yaz('VP13',{kullaniciAd:'Başka Ad'}));
  const {Timestamp}=await import('firebase/firestore');
  await assertFails(yaz('VP14',{zaman:Timestamp.fromMillis(Date.now()-86400000)}));
  await assertFails(setDoc(doc(db,'posIslemleri','VP15'),islemVerisi('VP16')));
  await assertFails(yaz('vp17',{posSiparisNo:'vp17'}));
  await assertFails(yaz('VP18',{sonuc:'belki'}));
  await assertFails(yaz('VP19',{tutarKurus:-1}));
  await assertFails(yaz('VP20',{numara:'4111111111111111'}));
  await assertFails(yaz('VP21',{aciklama:'satır\nsonu'}));
  await assertFails(setDoc(doc(db,'posGirisleri','kisa'),girisVerisi()));
  await assertFails(setDoc(doc(dbFor('pasif'),'posGirisleri','B'.repeat(20)),girisVerisi({kullaniciId:'pasif'})));
  await assertFails(setDoc(doc(dbFor(null),'posGirisleri','C'.repeat(20)),girisVerisi()));
});
test('Silinmiş cariye kayıt eklenemez',async()=>{
  await tahsilatCari();
  await env.withSecurityRulesDisabled(async ctx=>{await updateDoc(doc(ctx.firestore(),'cariler','kendi'),{silindi:true});});
  await assertFails(setDoc(doc(dbFor(uid),'posIslemleri','VP30'),islemVerisi('VP30')));
});
test('Kayıtları sahibi ve yönetici okur; satıcı yalnız kendi kayıtlarını listeler',async()=>{
  await tahsilatCari();const db=dbFor(uid);
  await setDoc(doc(db,'posIslemleri','VP40'),islemVerisi('VP40'));
  await setDoc(doc(db,'posGirisleri','D'.repeat(20)),girisVerisi());
  const {orderBy,Timestamp}=await import('firebase/firestore');
  const gun=c=>query(collection(c,'posIslemleri'),where('zaman','>=',Timestamp.fromMillis(Date.now()-86400000)),orderBy('zaman'));
  await assertSucceeds(getDocs(query(collection(db,'posIslemleri'),where('kullaniciId','==',uid),
    where('zaman','>=',Timestamp.fromMillis(Date.now()-86400000)),orderBy('zaman'))));
  await assertFails(getDocs(gun(db)));
  await assertSucceeds(getDocs(gun(dbFor('admin'))));
  await assertSucceeds(getDocs(query(collection(dbFor('admin'),'posGirisleri'))));
  await assertFails(getDoc(doc(dbFor(other),'posIslemleri','VP40')));
  await assertFails(getDoc(doc(dbFor(other),'posGirisleri','D'.repeat(20))));
  await assertFails(getDocs(query(collection(dbFor(other),'posIslemleri'),where('kullaniciId','==',uid))));
  // Başkasının kaydıyla aynı numara: okunamaz, üstüne yazılamaz.
  await env.withSecurityRulesDisabled(async ctx=>{
    await setDoc(doc(ctx.firestore(),'cariler','b-cari'),{...record(other,'0000000002'),kimlikNo:'0000000002'});
  });
  await assertFails(setDoc(doc(dbFor(other),'posIslemleri','VP40'),{...islemVerisi('VP40'),kullaniciId:other,
    cariId:'b-cari',kimlikNo:'0000000002'}));
});
test('Yönetici başkasına atanmış cari için kendi adına kayıt ekleyebilir',async()=>{
  await tahsilatCari();
  await assertSucceeds(setDoc(doc(dbFor('admin'),'posIslemleri','VP50'),{...islemVerisi('VP50'),kullaniciId:'admin'}));
});
