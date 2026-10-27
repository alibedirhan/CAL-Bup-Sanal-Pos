package com.bup.sanalpos

import android.app.KeyguardManager
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Kanal hatası: yalnız sabit kod taşır; kart, anahtar veya istisna metni taşımaz. */
class GuvenlikHatasi(val kod: String) : Exception(kod)

/**
 * Kart kasasının şifrelemesi (docs/ANDROID_PLANI.md §4.1). Her kullanıcıya
 * Android Keystore'da dışa aktarılamaz AES-256-GCM anahtarı; varsa StrongBox
 * (ayrı güvenlik yongası). Anahtar yalnız telefonun kilidi açıkken kullanılır.
 * Ekran kilidi olmayan telefonda kart saklanmaz ve açılmaz. Kayıt kuralları
 * (taslak, ek doğrulama verisi, bozulma reddi) Dart'ta: lib/data/kasa/.
 */
object KasaAnahtari {
    private const val DEPO = "AndroidKeyStore"
    private const val DONUSUM = "AES/GCM/NoPadding"

    fun takma(uid: String) = "bup-kasa-" + ozet(uid)

    fun sifrele(ctx: Context, uid: String, ekVeri: ByteArray, duz: ByteArray, olustur: Boolean): Pair<ByteArray, ByteArray> {
        kilitVarMi(ctx)
        val anahtar = anahtar(takma(uid)) ?: if (olustur) uret(takma(uid)) else throw GuvenlikHatasi("anahtar_yok")
        val c = Cipher.getInstance(DONUSUM)
        // IV'yi Keystore üretir (rastgele IV zorunlu): aynı IV iki kez kullanılamaz.
        c.init(Cipher.ENCRYPT_MODE, anahtar)
        c.updateAAD(ekVeri)
        val veri = c.doFinal(duz)
        return c.iv to veri
    }

    fun coz(ctx: Context, uid: String, ekVeri: ByteArray, iv: ByteArray, veri: ByteArray): ByteArray {
        kilitVarMi(ctx)
        val anahtar = anahtar(takma(uid)) ?: throw GuvenlikHatasi("anahtar_yok")
        if (iv.size != 12) throw GuvenlikHatasi("veri")
        val c = Cipher.getInstance(DONUSUM)
        c.init(Cipher.DECRYPT_MODE, anahtar, GCMParameterSpec(128, iv))
        c.updateAAD(ekVeri)
        return c.doFinal(veri)
    }

    /** Testler ve kasanın tamamen kaldırılması için; kayıtlar ayrıca silinir. */
    fun sil(uid: String) {
        keystore().deleteEntry(takma(uid))
    }

    private fun kilitVarMi(ctx: Context) {
        val km = ctx.getSystemService(KeyguardManager::class.java)
        if (km == null || !km.isDeviceSecure) throw GuvenlikHatasi("ekran_kilidi")
    }

    internal fun keystore(): KeyStore = KeyStore.getInstance(DEPO).apply { load(null) }

    private fun anahtar(takma: String) = keystore().getKey(takma, null) as SecretKey?

    private fun uret(takma: String): SecretKey {
        fun ozellik(guvenlikYongasi: Boolean) =
            KeyGenParameterSpec.Builder(takma, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .setUnlockedDeviceRequired(true)
                .setIsStrongBoxBacked(guvenlikYongasi)
                .build()
        val uretici = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, DEPO)
        return try {
            uretici.init(ozellik(true))
            uretici.generateKey()
        } catch (_: StrongBoxUnavailableException) {
            uretici.init(ozellik(false))
            uretici.generateKey()
        }
    }

    /** Takma ada kullanıcı kimliği yazılmaz; yalnız özeti. */
    internal fun ozet(uid: String): String =
        MessageDigest.getInstance("SHA-256").digest(uid.toByteArray(Charsets.UTF_8))
            .take(16).joinToString("") { "%02x".format(it) }
}
