package com.bup.sanalpos

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

/** Kanal yanıtları Flutter'ın standart kodlayıcısıyla gerçekten kodlanabilmeli. */
@RunWith(AndroidJUnit4::class)
class GuvenlikKanaliTest {
    @Test
    fun degerDondurmeyenIsKanaldaNullOlur_kodlanabilir() {
        assertNull(GuvenlikKanali.kanalDegeri(Unit))
        for (deger in listOf(Unit, true, "tamam", byteArrayOf(1, 2), mapOf("iv" to byteArrayOf(3)))) {
            val v = GuvenlikKanali.kanalDegeri(deger)
            val tampon = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(v)
            (tampon as java.nio.Buffer).flip()
            val geri: Any? = StandardMethodCodec.INSTANCE.decodeEnvelope(tampon)
            when (v) {
                is ByteArray -> assertArrayEquals(v, geri as ByteArray)
                is Map<*, *> -> assertArrayEquals(v["iv"] as ByteArray, (geri as Map<*, *>)["iv"] as ByteArray)
                else -> assertEquals(v, geri)
            }
        }
    }
}
