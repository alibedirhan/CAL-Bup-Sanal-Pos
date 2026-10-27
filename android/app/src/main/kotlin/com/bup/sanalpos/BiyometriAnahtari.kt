package com.bup.sanalpos

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Parmak izi/yüzle kilit açma (docs/ANDROID_PLANI.md §6.2). Yalnız güçlü
 * biyometri (BIOMETRIC_STRONG). Anahtar her kullanımda biyometri ister ve
 * telefona yeni parmak izi/yüz eklenince kalıcı olarak geçersizleşir (kişisel
 * telefonda başkasının parmak izi eklenebilir). Başarı, anahtarla gerçekten
 * şifreleme yapılmasıyla kanıtlanır; yalnız "evet" yanıtına güvenilmez.
 * Kurallar (7 gün, yeniden başlatma) Dart'ta: lib/domain/biyometri.dart.
 */
object BiyometriAnahtari {
    private const val DONUSUM = "AES/GCM/NoPadding"

    private fun takma(uid: String) = "bup-biyo-" + KasaAnahtari.ozet(uid)

    fun destekli(ctx: Context) =
        BiometricManager.from(ctx).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS

    /** Telefonun açılış sayacı; yeniden başlatmada artar (yoksa -1: biyometri kapalı sayılır). */
    fun acilis(ctx: Context) = Settings.Global.getInt(ctx.contentResolver, Settings.Global.BOOT_COUNT, -1)

    /** Önceki anahtar silinip yenisi üretilir. Cihaz desteklemiyorsa `false`. */
    fun etkinlestir(ctx: Context, uid: String): Boolean {
        sil(uid)
        if (!destekli(ctx)) return false
        val b = KeyGenParameterSpec.Builder(takma(uid), KeyProperties.PURPOSE_ENCRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .setUnlockedDeviceRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            b.setUserAuthenticationValidityDurationSeconds(-1)
        }
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(b.build())
            generateKey()
        }
        return true
    }

    fun sil(uid: String) {
        KasaAnahtari.keystore().deleteEntry(takma(uid))
    }

    /**
     * Sonuç: tamam, iptal (kişi kapattı / "Şifreyle aç"), gecersiz (anahtar yok
     * veya yeni biyometri eklendi; anahtar silinir), kilit (çok fazla hatalı
     * deneme), hata. Geri çağrı tam bir kez çalışır.
     */
    fun dogrula(etkinlik: FragmentActivity, uid: String, baslik: String, aciklama: String, sonuc: (String) -> Unit) {
        val anahtar = KasaAnahtari.keystore().getKey(takma(uid), null) as SecretKey?
            ?: return sonuc("gecersiz")
        val sifre = Cipher.getInstance(DONUSUM)
        try {
            sifre.init(Cipher.ENCRYPT_MODE, anahtar)
        } catch (_: KeyPermanentlyInvalidatedException) {
            sil(uid)
            return sonuc("gecersiz")
        } catch (_: Exception) {
            return sonuc("hata")
        }
        var bitti = false
        fun bitir(s: String) {
            if (!bitti) {
                bitti = true
                sonuc(s)
            }
        }
        val geri = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                val c = r.cryptoObject?.cipher
                bitir(
                    try {
                        if (c == null) "hata" else c.doFinal(ByteArray(16)).let { "tamam" }
                    } catch (_: Exception) {
                        "hata"
                    },
                )
            }

            override fun onAuthenticationError(kod: Int, metin: CharSequence) {
                bitir(
                    when (kod) {
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_CANCELED,
                        -> "iptal"
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
                        -> "kilit"
                        // Parmak izleri silindi / donanım yok: şifre gerekir. Geçici
                        // donanım hatası (HW_UNAVAILABLE) "hata"dır, kayıt kalır.
                        BiometricPrompt.ERROR_NO_BIOMETRICS,
                        BiometricPrompt.ERROR_HW_NOT_PRESENT,
                        -> "gecersiz"
                        else -> "hata"
                    },
                )
            }
        }
        val bilgi = BiometricPrompt.PromptInfo.Builder()
            .setTitle(baslik)
            .setSubtitle(aciklama)
            .setNegativeButtonText("Şifreyle aç")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()
        BiometricPrompt(etkinlik, ContextCompat.getMainExecutor(etkinlik), geri)
            .authenticate(bilgi, BiometricPrompt.CryptoObject(sifre))
    }
}
