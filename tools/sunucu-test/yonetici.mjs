import { writeFile, chmod, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { adminApp, cloudFetch, projectId } from './bulut.mjs';

// Yalnız ilk yönetici oluşturma. Sonraki kullanıcılar uygulamanın yönetici ekranındadır.
const [command,email,outFile]=process.argv.slice(2);
if(command!=='ilk-yonetici'||!email?.includes('@')||!outFile) throw Error('Kullanım: node yonetici.mjs ilk-yonetici EPOSTA PROJE_DISI_HTML_YOLU');
const target=resolve(outFile),root=resolve(fileURLToPath(new URL('../..',import.meta.url)));
if(target.startsWith(`${root}/`)) throw Error('Şifre bağlantısını kaynak projesinin dışında saklayın.');
const app=adminApp(),auth=getAuth(app);
const documents=`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const current=await cloudFetch(`${documents}:runQuery`,{method:'POST',body:{structuredQuery:{
  from:[{collectionId:'kullanicilar'}],where:{fieldFilter:{field:{fieldPath:'yonetici'},op:'EQUAL',value:{booleanValue:true}}},limit:1,
}}});
if(current.status!==200) throw Error(`Yönetici denetimi başarısız: ${current.status}`);
if(current.data.some(r=>r.document)) throw Error('İlk yönetici zaten var. Bu araç yeniden yetki yükseltmez.');
const user=await auth.createUser({email,password:randomBytes(48).toString('base64url'),displayName:'Yönetici'});
const now=new Date().toISOString();
const created=await cloudFetch(`${documents}/kullanicilar?documentId=${encodeURIComponent(user.uid)}`,{method:'POST',body:{fields:{
  ad:{stringValue:'Yönetici'},eposta:{stringValue:email.trim().toLowerCase()},yonetici:{booleanValue:true},aktif:{booleanValue:true},
  olusturma:{timestampValue:now},guncelleme:{timestampValue:now},
}}});
if(created.status!==200) {
  await auth.deleteUser(user.uid);
  throw Error(`Yönetici profili oluşturulamadı: ${created.status}`);
}
const url=await auth.generatePasswordResetLink(email,{url:`https://${projectId}.web.app/`});
const escape=s=>s.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
await mkdir(dirname(target),{recursive:true,mode:0o700});
await writeFile(target,`<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="referrer" content="no-referrer"><title>İlk giriş şifresi</title><h1>BUP Sanal POS</h1><p>Yönetici hesabının şifresini aşağıdaki bağlantıdan kendin belirle. Bu dosyayı paylaşma; işlemden sonra sil.</p><p><a href="${escape(url)}" rel="noreferrer">Şifremi belirle</a></p></html>`,{mode:0o600,flag:'wx'});
await chmod(target,0o600);
console.log('Yönetici hesabı açıldı. Şifre bağlantısı yalnız belirtilen yerel dosyaya yazıldı; e-posta gönderilmedi.');
