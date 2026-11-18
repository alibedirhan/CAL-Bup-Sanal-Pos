import assert from 'node:assert/strict';
import { cloudFetch,projectId } from './bulut.mjs';
const url=`https://identitytoolkit.googleapis.com/admin/v2/projects/${projectId}/config`;
const once=await cloudFetch(url);
assert.equal(once.status,200,'Önce Firebase konsolunda Authentication → Başlayın işlemini tamamlayın.');
const r=await cloudFetch(`${url}?updateMask=signIn.email,signIn.anonymous,signIn.phoneNumber,passwordPolicyConfig,emailPrivacyConfig,authorizedDomains`,{
  method:'PATCH',body:{
    // Anonim giriş yalnız rota terminal kimliği içindir (docs/ROTA_MIMARI.md M2, 17 Kasım 2026 Ali'nin
    // onayıyla açıldı). Anonim hesabın Sanal POS verisine erişimi yoktur (kurallar profil ister).
    signIn:{email:{enabled:true,passwordRequired:true},anonymous:{enabled:true},phoneNumber:{enabled:false}},
    passwordPolicyConfig:{passwordPolicyEnforcementState:'ENFORCE',forceUpgradeOnSignin:true,
      passwordPolicyVersions:[{customStrengthOptions:{minPasswordLength:6,maxPasswordLength:128}}]},
    emailPrivacyConfig:{enableImprovedEmailPrivacy:true},
    // cal-bup-ali.web.app: CAL_bup Rota sekmesinin Google girişi (ROUTE_PLANI K33, 18 Kasım 2026).
    authorizedDomains:[`${projectId}.web.app`,`${projectId}.firebaseapp.com`,'cal-bup-ali.web.app'],
  },
});
assert.equal(r.status,200,`Giriş ayarları uygulanamadı: ${r.data.error?.status??r.status}`);
assert.equal(r.data.passwordPolicyConfig?.passwordPolicyEnforcementState,'ENFORCE');
assert.equal(r.data.passwordPolicyConfig?.passwordPolicyVersions?.[0]?.customStrengthOptions?.minPasswordLength,6);
console.log('Giriş yöntemi, 6–128 karakter şifre politikası ve hesap gizliliği ayarları doğrulandı.');
