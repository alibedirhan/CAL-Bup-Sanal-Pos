package com.bup.sanalpos.rota

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Kalıcı kuyruk (ROTA_MIMARI §5): sıra, yeniden açılış, sınırlar. Yalnız emülatör, yapay veri. */
@RunWith(AndroidJUnit4::class)
class NoktaKuyruguTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext
    private val dosya = "rota_kuyruk_test.db"
    private lateinit var k: NoktaKuyrugu

    private fun yeni(n: Long = 0, z: Long = 1_763_366_400_000) =
        Nokta(n, z, 38.4612345, 27.2198765, 4.5, 11.25, 87.5, null, NoktaKaynagi.GPS, sahte = false)

    @Before fun hazirla() {
        ctx.deleteDatabase(dosya)
        k = NoktaKuyrugu(ctx, dosya, enCokKayit = 10, enEskiMs = 1_000_000)
    }

    @After fun temizle() {
        k.close()
        ctx.deleteDatabase(dosya)
    }

    @Test fun siraOrtakVeBosluksuz() {
        val a = k.ekle(yeni())
        val o = k.ekle(OlayTuru.KONUM_KAPANDI, 5)
        val b = k.ekle(yeni(z = 7).copy(kaynak = NoktaKaynagi.AG, sahte = true, hiz = null))
        assertEquals(listOf(1L, 2L, 3L), listOf(a.sira, o.sira, b.sira))
        val bas = k.bas(10)
        assertEquals(listOf(KuyrukKaydi.N(a), KuyrukKaydi.O(o), KuyrukKaydi.N(b)), bas)
        val p = Parca.olustur("cihaz1", bas)!!
        assertEquals(1L, p.ilk)
        assertEquals(3L, p.son)
    }

    @Test fun yenidenAcilincaKayitlarDurur() {
        repeat(3) { k.ekle(yeni()) }
        k.close()
        k = NoktaKuyrugu(ctx, dosya, enCokKayit = 10, enEskiMs = 1_000_000)
        assertEquals(3L, k.sayi())
        // Silinen numara yeniden kullanılmaz.
        k.sil(1, 3)
        assertEquals(4L, k.ekle(yeni()).sira)
    }

    @Test fun kmSayaciSaklanir() {
        val a = k.ekle(yeni().copy(km = 12_345))
        val b = k.ekle(yeni())
        assertEquals(listOf<Long?>(12_345, null), k.bas(10).map { (it as KuyrukKaydi.N).nokta.km })
        assertEquals(12_345L, a.km)
        assertNull(b.km)
    }

    /** 0.13.2 (şema 1) kuyruğu 0.13.3'e geçerken gönderilmemiş kayıtlar kaybolmaz. */
    @Test fun eskiSemadanGecisVeriyiKorur() {
        k.close()
        ctx.deleteDatabase(dosya)
        val eski = android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(ctx.getDatabasePath(dosya), null)
        eski.execSQL(
            """CREATE TABLE kayit (sira INTEGER PRIMARY KEY AUTOINCREMENT, tur INTEGER NOT NULL, zaman INTEGER NOT NULL,
                en REAL, boy REAL, dog REAL, hiz REAL, yon REAL, yuk REAL, kay TEXT, sahte INTEGER, olay TEXT, ayrinti TEXT)""",
        )
        eski.execSQL("INSERT INTO kayit (tur, zaman, en, boy, dog, hiz, kay, sahte) VALUES (0, 7, 38.4, 27.2, 5, 3.5, 'g', 0)")
        eski.execSQL("INSERT INTO kayit (tur, zaman, olay, ayrinti) VALUES (1, 8, 'acilis', NULL)")
        eski.version = 1
        eski.close()
        k = NoktaKuyrugu(ctx, dosya, enCokKayit = 10, enEskiMs = 1_000_000)
        val bas = k.bas(10)
        assertEquals(listOf(1L, 2L), bas.map { it.sira })
        val n = (bas[0] as KuyrukKaydi.N).nokta
        assertNull(n.km)
        assertEquals(3.5, n.hiz!!, 0.0)
        assertEquals(OlayTuru.ACILIS, (bas[1] as KuyrukKaydi.O).olay.tur)
        // Geçişten sonra sıra kaldığı yerden sürer, km yazılır.
        val yeniNokta = k.ekle(yeni().copy(km = 99))
        assertEquals(3L, yeniNokta.sira)
        assertEquals(99L, (k.bas(10)[2] as KuyrukKaydi.N).nokta.km)
    }

    @Test fun silmeYalnizAraligi() {
        repeat(5) { k.ekle(yeni()) }
        assertEquals(2, k.sil(2, 3))
        assertEquals(listOf(1L, 4L, 5L), k.bas(10).map { it.sira })
    }

    @Test fun eskiKayitlarOlaylaSilinir() {
        k.ekle(yeni(z = 100))
        k.ekle(OlayTuru.ACILIS, 200)
        k.ekle(yeni(z = 2_000_000))
        val olay = k.bakim(simdiMs = 1_500_000)!!
        assertEquals(OlayTuru.KUYRUK_TASTI, olay.tur)
        assertEquals(listOf(3L, 4L), k.bas(10).map { it.sira })
        assertTrue(olay.ayrinti!!.startsWith("2 kayıt"))
        assertNull(k.bakim(simdiMs = 1_500_000))
    }

    @Test fun sinirAsilincaEnEskilerSilinir() {
        repeat(15) { k.ekle(yeni(z = 2_000_000)) }
        val olay = k.bakim(simdiMs = 2_000_000)!!
        val kalan = k.bas(100)
        // Sınır 10: 6 en eski silindi, yerine 1 olay eklendi → toplam tam 10; ikinci bakım bir şey yapmaz.
        assertEquals((7L..15L).toList() + 16L, kalan.map { it.sira })
        assertEquals(KuyrukKaydi.O(olay), kalan.last())
        assertEquals(10L, k.sayi())
        assertNull(k.bakim(simdiMs = 2_000_000))
    }

    @Test fun ayrintiSinirlanir() {
        val o = k.ekle(OlayTuru.SAAT_DEGISTI, 1, "x".repeat(200))
        assertEquals(Olay.AYRINTI_EN_COK, o.ayrinti!!.length)
        assertEquals(KuyrukKaydi.O(o), k.bas(1).single())
    }
}
