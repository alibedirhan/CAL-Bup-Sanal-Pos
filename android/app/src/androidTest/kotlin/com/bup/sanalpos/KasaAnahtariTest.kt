package com.bup.sanalpos

import android.security.keystore.KeyInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Gerçek Android Keystore üzerinde kasa şifrelemesi. Emülatörde ekran kilidi
 * (PIN) açık çalıştırılır: `adb shell locksettings set-pin 1234`
 * (tools/android_test.sh kurar ve kaldırır). Yalnız yapay veri.
 */
@RunWith(AndroidJUnit4::class)
class KasaAnahtariTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext
    private val ek = "bup-pos-kart|test".toByteArray()
    private val duz = """{"numara":"4111111111111111","sahibi":"","telefon":""}""".toByteArray()

    @Before
    @After
    fun temizle() {
        for (uid in listOf("test-u1", "test-u2")) KasaAnahtari.sil(uid)
    }

    private fun hata(kod: String, blok: () -> Unit) {
        try {
            blok()
            fail("$kod bekleniyordu")
        } catch (e: GuvenlikHatasi) {
            assertEquals(kod, e.kod)
        }
    }

    @Test
    fun sifreliVeriGeriAcilir_ivRastgele_metinGorunmez() {
        val (iv1, veri1) = KasaAnahtari.sifrele(ctx, "test-u1", ek, duz, true)
        val (iv2, veri2) = KasaAnahtari.sifrele(ctx, "test-u1", ek, duz, false)
        assertEquals(12, iv1.size)
        assertFalse(iv1.contentEquals(iv2))
        assertFalse(veri1.contentEquals(veri2))
        assertEquals(duz.size + 16, veri1.size)
        assertFalse(String(veri1, Charsets.ISO_8859_1).contains("4111"))
        assertArrayEquals(duz, KasaAnahtari.coz(ctx, "test-u1", ek, iv1, veri1))
        assertArrayEquals(duz, KasaAnahtari.coz(ctx, "test-u1", ek, iv2, veri2))
    }

    @Test
    fun ekVeriVeyaSifreliVeriDegisirseAcilmaz() {
        val (iv, veri) = KasaAnahtari.sifrele(ctx, "test-u1", ek, duz, true)
        for ((e, v, i) in listOf(
            Triple("baska".toByteArray(), veri, iv),
            Triple(ek, veri.copyOf().also { it[0] = (it[0] + 1).toByte() }, iv),
            Triple(ek, veri, iv.copyOf().also { it[0] = (it[0] + 1).toByte() }),
        )) {
            try {
                KasaAnahtari.coz(ctx, "test-u1", e, i, v)
                fail("açılmamalıydı")
            } catch (_: AEADBadTagException) {
            }
        }
    }

    @Test
    fun anahtarKullaniciyaOzel_istenmedenUretilmez_silinince_acilmaz() {
        val (iv, veri) = KasaAnahtari.sifrele(ctx, "test-u1", ek, duz, true)
        hata("anahtar_yok") { KasaAnahtari.coz(ctx, "test-u2", ek, iv, veri) }
        hata("anahtar_yok") { KasaAnahtari.sifrele(ctx, "test-u2", ek, duz, false) }
        KasaAnahtari.sil("test-u1")
        hata("anahtar_yok") { KasaAnahtari.coz(ctx, "test-u1", ek, iv, veri) }
    }

    @Test
    fun anahtarDisaAktarilamaz_ozellikleriDogru() {
        KasaAnahtari.sifrele(ctx, "test-u1", ek, duz, true)
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val takma = KasaAnahtari.takma("test-u1")
        assertFalse(takma.contains("test-u1"))
        val anahtar = ks.getKey(takma, null) as SecretKey
        assertNull(anahtar.encoded)
        val bilgi = SecretKeyFactory.getInstance(anahtar.algorithm, "AndroidKeyStore")
            .getKeySpec(anahtar, KeyInfo::class.java) as KeyInfo
        assertEquals(256, bilgi.keySize)
        assertFalse(bilgi.isUserAuthenticationRequired)
    }
}
