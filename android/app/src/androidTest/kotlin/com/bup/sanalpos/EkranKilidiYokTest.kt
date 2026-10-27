package com.bup.sanalpos

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Ekran kilidi olmayan telefonda kart saklanmaz. Yalnız kilit kaldırılmışken
 * ayrı çalıştırılır (tools/android_test.sh, `-e class ...EkranKilidiYokTest`).
 */
@RunWith(AndroidJUnit4::class)
class EkranKilidiYokTest {
    @Test
    fun kilitsizTelefondaKartSifrelenmez() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        try {
            KasaAnahtari.sifrele(ctx, "test-kilitsiz", "e".toByteArray(), "d".toByteArray(), true)
            fail("ekran kilidi yokken şifrelememeliydi")
        } catch (e: GuvenlikHatasi) {
            assertEquals("ekran_kilidi", e.kod)
        } finally {
            KasaAnahtari.sil("test-kilitsiz")
        }
    }
}
