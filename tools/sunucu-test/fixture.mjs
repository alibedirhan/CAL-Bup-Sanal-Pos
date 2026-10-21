import assert from 'node:assert/strict';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
export const parola = 'YapayDenemeSifresi-2026!';
export async function fixture() {
  process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9098';
  process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8088';
  const proje='demo-bup-pos'; assert.ok(proje.startsWith('demo-'));
  await fetch(`http://127.0.0.1:9098/emulator/v1/projects/${proje}/accounts`,{method:'DELETE'});
  await fetch(`http://127.0.0.1:8088/emulator/v1/projects/${proje}/databases/(default)/documents`,{method:'DELETE'});
  const app=getApps()[0]??initializeApp({projectId:proje});
  const auth=getAuth(app),db=getFirestore(app);
  for(const [id,email,admin] of [['admin','admin@example.test',true],['satici-a','satici-a@example.test',false],['satici-b','satici-b@example.test',false]]) {
    await auth.createUser({uid:id,email,password:parola});
    await db.collection('kullanicilar').doc(id).set({ad:admin?'Örnek Yönetici':`Örnek ${id}`,eposta:email,yonetici:admin,aktif:true,olusturma:FieldValue.serverTimestamp(),guncelleme:FieldValue.serverTimestamp()});
  }
  return {db,auth};
}
