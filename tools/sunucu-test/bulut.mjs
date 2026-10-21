// Firebase CLI'nin mevcut oturumunu kullanır; parola veya hizmet anahtarı üretmez.
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { initializeApp } from 'firebase-admin/app';
const require = createRequire(import.meta.url);
const root = execFileSync('npm', ['root', '-g'], { encoding: 'utf8' }).trim();
const cliAuth = require(join(root, 'firebase-tools/lib/auth.js'));
export const projectId = 'bup-sanal-pos-izmir';
async function token() {
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw Error('Önce firebase login çalıştırın.');
  return cliAuth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
}
export async function cloudFetch(path, { method = 'GET', body } = {}) {
  const t = await token();
  const response = await fetch(path, { method, headers: {
    Authorization: `Bearer ${t.access_token}`, 'Content-Type': 'application/json',
  }, ...(body ? { body: JSON.stringify(body) } : {}) });
  const data = await response.json();
  return { status: response.status, data };
}
export function adminApp() {
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Canlı yönetim aracında emülatör değişkeni olmamalı.');
  return initializeApp({ projectId, credential: {
    async getAccessToken() {
      const t = await token();
      return { access_token: t.access_token, expires_in: 3500 };
    },
  }});
}
