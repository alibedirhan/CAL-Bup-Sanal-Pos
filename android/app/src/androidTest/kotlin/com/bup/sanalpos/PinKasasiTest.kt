package com.bup.sanalpos

import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Uygulama PIN'li kasa (ekran kilidi olmayan telefon). Yalnız kilit kaldırılmışken
 * çalıştırılır (tools/android_test.sh "Ekran kilidi yokken"). Yalnız yapay veri.
 */
@RunWith(AndroidJUnit4::class)
class PinKasasiTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext
    private val uid = "test-pin"
    private val ek = "bup-pos-kart|test".toByteArray()
    private val duz = """{"numara":"4111111111111111","sahibi":"","telefon":""}""".toByteArray()
    private val pinDosyasi get() = File(ctx.noBackupFilesDir, "kart-pin/${KasaAnahtari.ozet(uid)}.json")

    @Before
    @After
    fun temizle() {
        PinKasasi.sil(ctx, uid)
        KasaAnahtari.sil(uid)
        PinKasasi.kapat()
    }

    private fun hata(kod: String, blok: () -> Unit) {
        try {
            blok()
            fail("$kod bekleniyordu")
        } catch (e: GuvenlikHatasi) {
            assertEquals(kod, e.kod)
        }
    }

    /** Bekleme süresini atlar (testte dakikalarca beklenmez); sayaç korunur. */
    private fun beklemeyiAtla() {
        val k = JSONObject(pinDosyasi.readText())
        pinDosyasi.writeText(k.put("beklemeSonu", 0L).toString())
    }

    @Test
    fun kurulumSifreleCozVeOturum() {
        assertFalse(KasaAnahtari.kilitli(ctx))
        assertEquals("kur", PinKasasi.durum(ctx, uid)["mod"])
        hata("pin_bicim") { PinKasasi.kur(ctx, uid, "12345") }
        PinKasasi.kur(ctx, uid, "482915")
        assertEquals("pin", PinKasasi.durum(ctx, uid)["mod"])
        assertEquals(true, PinKasasi.durum(ctx, uid)["oturum"])
        hata("pin_kurulamaz") { PinKasasi.kur(ctx, uid, "111111") }

        val (iv, veri) = PinKasasi.sifrele(uid, ek, duz)
        assertArrayEquals(duz, PinKasasi.coz(uid, ek, iv, veri))
        // PIN dosyasında PIN ve kart yok.
        val icerik = pinDosyasi.readText()
        assertFalse(icerik.contains("482915") || icerik.contains("4111"))

        PinKasasi.kapat()
        assertEquals(false, PinKasasi.durum(ctx, uid)["oturum"])
        hata("pin_gerekli") { PinKasasi.coz(uid, ek, iv, veri) }
        assertEquals("tamam", PinKasasi.dogrula(ctx, uid, "482915")["sonuc"])
        assertArrayEquals(duz, PinKasasi.coz(uid, ek, iv, veri))
        // Ek doğrulama verisi bağlıdır: başka karta taşınan kayıt açılmaz.
        try {
            PinKasasi.coz(uid, "baska".toByteArray(), iv, veri)
            fail("başka ek veriyle açılmamalıydı")
        } catch (_: Exception) {
        }
    }

    @Test
    fun yanlisPinBeklemeVeOnuncudaSilme() {
        PinKasasi.kur(ctx, uid, "482915")
        val (iv, veri) = PinKasasi.sifrele(uid, ek, duz)
        val ad = Base64.encodeToString(uid.toByteArray(), Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        val kasa = File(ctx.noBackupFilesDir, "kart-kasasi/$ad.json")
        kasa.parentFile?.mkdirs()
        kasa.writeText("{}")
        PinKasasi.kapat()

        for (n in 1..4) {
            val r = PinKasasi.dogrula(ctx, uid, "000000")
            assertEquals("yanlis", r["sonuc"])
            assertEquals(10 - n, r["kalan"])
            assertEquals(0L, r["bekleme"])
        }
        // Doğru PIN sayacı sıfırlar.
        assertEquals("tamam", PinKasasi.dogrula(ctx, uid, "482915")["sonuc"])
        assertEquals(10, PinKasasi.durum(ctx, uid)["kalan"])
        PinKasasi.kapat()

        for (n in 1..9) {
            val r = PinKasasi.dogrula(ctx, uid, "000000")
            assertEquals("yanlis", r["sonuc"])
            if (n >= 5) {
                assertTrue((r["bekleme"] as Long) > 0)
                // Beklerken doğru PIN de denenemez ve sayaç artmaz.
                val b = PinKasasi.dogrula(ctx, uid, "482915")
                assertEquals("bekle", b["sonuc"])
                assertEquals(10 - n, b["kalan"])
                beklemeyiAtla()
            }
        }
        assertEquals("silindi", PinKasasi.dogrula(ctx, uid, "000000")["sonuc"])
        assertFalse(pinDosyasi.exists())
        assertFalse(kasa.exists())
        assertFalse(KasaAnahtari.anahtarVar(PinKasasi.takma(uid)))
        assertEquals("kur", PinKasasi.durum(ctx, uid)["mod"])
        hata("pin_gerekli") { PinKasasi.coz(uid, ek, iv, veri) }
    }

    @Test
    fun sayacDenemedenOnceArtar() {
        PinKasasi.kur(ctx, uid, "482915")
        PinKasasi.kapat()
        PinKasasi.dogrula(ctx, uid, "000000")
        assertEquals(1, JSONObject(pinDosyasi.readText()).getInt("yanlis"))
        assertEquals(9, PinKasasi.durum(ctx, uid)["kalan"])
    }
}
