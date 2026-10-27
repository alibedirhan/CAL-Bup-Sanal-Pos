package com.bup.sanalpos

import android.content.Context
import android.os.SystemClock
import android.util.Base64
import java.io.File
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import org.json.JSONObject

/**
 * Ekran kilidi olmayan telefonda kart kasası: uygulamanın 6 haneli PIN'i
 * (kullanıcı kararı, 27 Ekim 2026; docs/ANDROID_PLANI.md "Uygulama PIN'i").
 *
 * İki katman: iç katman PIN'den türetilen anahtar (PBKDF2-HMAC-SHA256, rastgele
 * tuz), dış katman Keystore'daki dışa aktarılamaz anahtar (telefona bağlı; dosya
 * kopyalansa da açılmaz, PIN denemesi yalnız bu telefonda yapılabilir). PIN
 * saklanmaz; doğrulama, sabit metnin PIN anahtarıyla şifrelenmiş hâlidir.
 * Yanlış sayacı kalıcıdır ve denemeden ÖNCE artırılır (deneme yarıda kesilse de
 * sayılır). [BEKLEME_ESIGI]. yanlıştan sonra artan bekleme, [SILME_ESIGI].
 * yanlışta bu kullanıcının kasası (anahtar, PIN kaydı, kart dosyası) silinir.
 * Türetilen anahtar yalnız bellekte: uygulama kilitlenince/çıkışta ([kapat]) ya
 * da [OTURUM_MS] dolunca unutulur. Bütün çağrılar kanalın tek iş parçacığında.
 */
object PinKasasi {
    const val UZUNLUK = 6
    const val BEKLEME_ESIGI = 5
    const val SILME_ESIGI = 10
    private const val TUR = 310_000
    private const val OTURUM_MS = 15 * 60 * 1000L
    private const val DONUSUM = "AES/GCM/NoPadding"
    private val DOGRULAMA = "bup-sanal-pos-pin-v1".toByteArray()
    private val rastgele = SecureRandom()
    private val oturumlar = HashMap<String, Pair<ByteArray, Long>>()

    fun takma(uid: String) = "bup-pin-" + KasaAnahtari.ozet(uid)

    private fun dosya(ctx: Context, uid: String) =
        File(ctx.noBackupFilesDir, "kart-pin/${KasaAnahtari.ozet(uid)}.json")

    /** Bu kullanıcının kasası uygulama PIN'iyle mi korunuyor. */
    fun kurulu(ctx: Context, uid: String) =
        dosya(ctx, uid).isFile && KasaAnahtari.anahtarVar(takma(uid))

    /**
     * mod: "pin" (PIN'li kasa), "kilit" (telefon kilidi; eski yol), "kur" (kilit
     * yok, kasa yok: ilk kartta PIN belirlenir), "kilit_kaldirildi" (kasa telefon
     * kilidiyle kurulmuş ama kilit kaldırılmış: kartlar açılamaz).
     */
    fun durum(ctx: Context, uid: String): Map<String, Any> {
        val kilit = KasaAnahtari.kilitli(ctx)
        val mod = when {
            kurulu(ctx, uid) -> "pin"
            KasaAnahtari.anahtarVar(KasaAnahtari.takma(uid)) -> if (kilit) "kilit" else "kilit_kaldirildi"
            kilit -> "kilit"
            else -> "kur"
        }
        val kayit = if (mod == "pin") oku(ctx, uid) else null
        return mapOf(
            "mod" to mod,
            "oturum" to (oturum(uid) != null),
            "kalan" to SILME_ESIGI - (kayit?.optInt("yanlis") ?: 0),
            "bekleme" to bekleme(kayit),
        )
    }

    fun kur(ctx: Context, uid: String, pin: String) {
        if (durum(ctx, uid)["mod"] != "kur") throw GuvenlikHatasi("pin_kurulamaz")
        bicim(pin)
        val tuz = ByteArray(16).also(rastgele::nextBytes)
        val anahtar = turet(pin, tuz)
        val (iv, dogrulayici) = icSifrele(anahtar, DOGRULAMA, uid.toByteArray())
        KasaAnahtari.uret(takma(uid), kilitGerekli = false)
        yaz(ctx, uid, JSONObject()
            .put("v", 1).put("tuz", b64(tuz)).put("iv", b64(iv))
            .put("dogrulayici", b64(dogrulayici)).put("yanlis", 0).put("beklemeSonu", 0L))
        ac(uid, anahtar)
    }

    /** Sonuç: {"sonuc": "tamam" | "yanlis" | "bekle" | "silindi", "kalan", "bekleme"}. */
    fun dogrula(ctx: Context, uid: String, pin: String): Map<String, Any> {
        bicim(pin)
        val kayit = oku(ctx, uid) ?: throw GuvenlikHatasi("pin_yok")
        val bekle = bekleme(kayit)
        if (bekle > 0) return mapOf("sonuc" to "bekle", "bekleme" to bekle, "kalan" to SILME_ESIGI - kayit.getInt("yanlis"))
        val yanlis = kayit.getInt("yanlis") + 1
        yaz(ctx, uid, kayit.put("yanlis", yanlis))
        val anahtar = turet(pin, coz64(kayit.getString("tuz")))
        val dogru = try {
            icCoz(anahtar, coz64(kayit.getString("iv")), coz64(kayit.getString("dogrulayici")), uid.toByteArray())
                .contentEquals(DOGRULAMA)
        } catch (_: AEADBadTagException) {
            false
        }
        if (dogru) {
            yaz(ctx, uid, kayit.put("yanlis", 0).put("beklemeSonu", 0L))
            ac(uid, anahtar)
            return mapOf("sonuc" to "tamam")
        }
        anahtar.fill(0)
        if (yanlis >= SILME_ESIGI) {
            sil(ctx, uid)
            return mapOf("sonuc" to "silindi")
        }
        if (yanlis >= BEKLEME_ESIGI) {
            // 30 sn, 1, 2, 4, 8 dk.
            val ms = 30_000L shl (yanlis - BEKLEME_ESIGI)
            yaz(ctx, uid, kayit.put("beklemeSonu", System.currentTimeMillis() + ms))
        }
        return mapOf("sonuc" to "yanlis", "kalan" to SILME_ESIGI - yanlis, "bekleme" to bekleme(kayit))
    }

    fun sifrele(uid: String, ekVeri: ByteArray, duz: ByteArray): Pair<ByteArray, ByteArray> {
        val pinAnahtari = oturum(uid) ?: throw GuvenlikHatasi("pin_gerekli")
        val (icIv, icVeri) = icSifrele(pinAnahtari, duz, ekVeri)
        val ic = icIv + icVeri
        try {
            val c = Cipher.getInstance(DONUSUM)
            c.init(Cipher.ENCRYPT_MODE, KasaAnahtari.anahtar(takma(uid)) ?: throw GuvenlikHatasi("anahtar_yok"))
            c.updateAAD(ekVeri)
            return c.iv to c.doFinal(ic)
        } finally {
            ic.fill(0)
        }
    }

    fun coz(uid: String, ekVeri: ByteArray, iv: ByteArray, veri: ByteArray): ByteArray {
        val pinAnahtari = oturum(uid) ?: throw GuvenlikHatasi("pin_gerekli")
        if (iv.size != 12) throw GuvenlikHatasi("veri")
        val c = Cipher.getInstance(DONUSUM)
        c.init(Cipher.DECRYPT_MODE, KasaAnahtari.anahtar(takma(uid)) ?: throw GuvenlikHatasi("anahtar_yok"), GCMParameterSpec(128, iv))
        c.updateAAD(ekVeri)
        val ic = c.doFinal(veri)
        try {
            if (ic.size < 12 + 16) throw GuvenlikHatasi("veri")
            return icCoz(pinAnahtari, ic.copyOfRange(0, 12), ic.copyOfRange(12, ic.size), ekVeri)
        } finally {
            ic.fill(0)
        }
    }

    /** Uygulama kilitlendi/çıkış: bellekteki PIN anahtarları silinir. */
    fun kapat() {
        oturumlar.values.forEach { it.first.fill(0) }
        oturumlar.clear()
    }

    /**
     * Kasanın tamamı: Keystore anahtarı, PIN kaydı ve kart dosyası (adı
     * lib/data/android/kart_kasasi.dart DosyaKasaDeposu ile aynı kuralla).
     * Sunucudaki kart özetleri kalır; kart bu telefonda yeniden eklenir.
     */
    fun sil(ctx: Context, uid: String) {
        oturumlar.remove(uid)?.first?.fill(0)
        KasaAnahtari.keystore().deleteEntry(takma(uid))
        dosya(ctx, uid).delete()
        val ad = Base64.encodeToString(uid.toByteArray(), Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        File(ctx.noBackupFilesDir, "kart-kasasi/$ad.json").delete()
    }

    private fun bicim(pin: String) {
        if (pin.length != UZUNLUK || !pin.all { it in '0'..'9' }) throw GuvenlikHatasi("pin_bicim")
    }

    private fun ac(uid: String, anahtar: ByteArray) {
        oturumlar.remove(uid)?.first?.fill(0)
        oturumlar[uid] = anahtar to SystemClock.elapsedRealtime() + OTURUM_MS
    }

    private fun oturum(uid: String): ByteArray? {
        val (anahtar, bitis) = oturumlar[uid] ?: return null
        if (SystemClock.elapsedRealtime() < bitis) return anahtar
        oturumlar.remove(uid)
        anahtar.fill(0)
        return null
    }

    private fun bekleme(kayit: JSONObject?): Long =
        maxOf(0L, (kayit?.optLong("beklemeSonu") ?: 0L) - System.currentTimeMillis())

    private fun turet(pin: String, tuz: ByteArray): ByteArray {
        val ozellik = PBEKeySpec(pin.toCharArray(), tuz, TUR, 256)
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(ozellik).encoded
        } finally {
            ozellik.clearPassword()
        }
    }

    private fun icSifrele(anahtar: ByteArray, duz: ByteArray, ekVeri: ByteArray): Pair<ByteArray, ByteArray> {
        val iv = ByteArray(12).also(rastgele::nextBytes)
        val c = Cipher.getInstance(DONUSUM)
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(anahtar, "AES"), GCMParameterSpec(128, iv))
        c.updateAAD(ekVeri)
        return iv to c.doFinal(duz)
    }

    private fun icCoz(anahtar: ByteArray, iv: ByteArray, veri: ByteArray, ekVeri: ByteArray): ByteArray {
        val c = Cipher.getInstance(DONUSUM)
        c.init(Cipher.DECRYPT_MODE, SecretKeySpec(anahtar, "AES"), GCMParameterSpec(128, iv))
        c.updateAAD(ekVeri)
        return c.doFinal(veri)
    }

    private fun oku(ctx: Context, uid: String): JSONObject? {
        val f = dosya(ctx, uid)
        if (!f.isFile) return null
        return try {
            JSONObject(f.readText()).takeIf { it.optInt("v") == 1 }
        } catch (_: Exception) {
            null
        } ?: throw GuvenlikHatasi("veri")
    }

    /** Önce geçici dosya, sonra yeniden adlandırma: kayıt yarım yazılmaz. */
    private fun yaz(ctx: Context, uid: String, kayit: JSONObject) {
        val f = dosya(ctx, uid)
        f.parentFile?.mkdirs()
        val gecici = File(f.path + ".yeni")
        gecici.writeText(kayit.toString())
        if (!gecici.renameTo(f)) throw GuvenlikHatasi("dosya")
    }

    private fun b64(b: ByteArray) = Base64.encodeToString(b, Base64.NO_WRAP)
    private fun coz64(s: String): ByteArray = Base64.decode(s, Base64.NO_WRAP)
}
