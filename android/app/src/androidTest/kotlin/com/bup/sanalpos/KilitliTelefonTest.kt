package com.bup.sanalpos

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Telefon kilitliyken (ekran kapalı, PIN'li) kasa anahtarı kullanılamaz
 * (setUnlockedDeviceRequired). Anahtar önce kilit açıkken üretilir
 * (`hazirla`), sonra telefon kilitlenip `kilitliyken` çalıştırılır; ikisi de
 * tools/android_test.sh tarafından sırayla çağrılır.
 */
@RunWith(AndroidJUnit4::class)
class KilitliTelefonTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun hazirla() {
        KasaAnahtari.sil(UID)
        KasaAnahtari.sifrele(ctx, UID, EK, DUZ, true)
    }

    @Test
    fun kilitliyken() {
        try {
            KasaAnahtari.sifrele(ctx, UID, EK, DUZ, false)
            fail("telefon kilitliyken anahtar kullanılmamalıydı")
        } catch (e: GuvenlikHatasi) {
            throw e
        } catch (_: Exception) {
            // Beklenen: Keystore DEVICE_LOCKED.
        } finally {
            KasaAnahtari.sil(UID)
        }
    }

    private companion object {
        const val UID = "test-kilitli"
        val EK = "e".toByteArray()
        val DUZ = "d".toByteArray()
    }
}
