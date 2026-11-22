package com.bup.sanalpos.rota

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** Km sayacı (M23): yapay GPS izleriyle. Gerçek yol uzunluğu her izde bilinir. */
class KmSayaciTest {
    private val en0 = 38.41
    private val boy0 = 27.14
    private val mEn = 111_195.0 // 1 derece enlem (m)
    private val mBoy = 111_195.0 * cos(Math.toRadians(en0))
    private val t0 = 1_795_200_000_000L

    /** (x, y) metre düzleminden GPS ölçümü. */
    private fun olcum(sn: Double, x: Double, y: Double, hiz: Double?, dog: Double = 5.0) = Nokta(
        0, t0 + (sn * 1000).toLong(), en0 + y / mEn, boy0 + x / mBoy, dog, hiz, null, null, NoktaKaynagi.GPS, false,
    )

    @Test fun duzYoldaSabitHiz() {
        val s = KmSayaci()
        for (i in 0..600) s.ekle(olcum(i.toDouble(), 10.0 * i, 0.0, 10.0))
        assertEquals(6_000.0, s.toplamM.toDouble(), 6_000 * 0.005)
    }

    /** Virajlı yol: 15 sn'lik kayıtlardan düz çizgi kısa kalır; saniyelik hız toplamı yolu tutturur. */
    @Test fun virajdaYolKisalmaz() {
        val s = KmSayaci()
        val r = 40.0
        val v = 8.0
        val sure = 600
        val kayitlar = ArrayList<Nokta>()
        for (i in 0..sure) {
            val a = v * i / r
            val n = olcum(i.toDouble(), r * cos(a), r * sin(a), v)
            s.ekle(n)
            if (i % 15 == 0) kayitlar += n
        }
        val gercek = v * sure
        assertEquals(gercek, s.toplamM.toDouble(), gercek * 0.01)
        val kayittan = kayitlar.zipWithNext { a, b -> Mesafe.metre(a.enlem, a.boylam, b.enlem, b.boylam) }.sum()
        assertTrue("15 sn'lik düz çizgi virajda yolu kısaltır: $kayittan", kayittan < gercek * 0.7)
    }

    /** Bir saat duran araç: konum ±10 m titrer, ölçülen hız 0–0,4 m/sn oynar. Yol sayılmamalı. */
    @Test fun duranAractaTitremeSayilmaz() {
        val s = KmSayaci()
        val r = Random(7)
        for (i in 0..3600) s.ekle(olcum(i.toDouble(), r.nextDouble(-10.0, 10.0), r.nextDouble(-10.0, 10.0), r.nextDouble(0.0, 0.4), 12.0))
        assertEquals(0L, s.toplamM)
    }

    /** Depoda seyrek ve hızsız ölçümler: doğruluk payı içindeki oynama sayılmaz. */
    @Test fun seyrekHizsizTitremeSayilmaz() {
        val s = KmSayaci()
        val r = Random(3)
        for (i in 0..240) s.ekle(olcum(i * 120.0, r.nextDouble(-8.0, 8.0), r.nextDouble(-8.0, 8.0), null, 10.0))
        assertEquals(0L, s.toplamM)
    }

    /** Doğruluk payı içinde ama yavaş yavaş uzaklaşan ölçümler: çapa kaymaz, eşik aşılınca birikmiş yol sayılır. */
    @Test fun yavasHareketBirikince() {
        val s = KmSayaci()
        for (i in 0..20) s.ekle(olcum(i * 120.0, 5.0 * i, 0.0, null, 5.0))
        assertEquals(100.0, s.toplamM.toDouble(), 16.0)
    }

    @Test fun bosluktaDuzCizgi() {
        val s = KmSayaci()
        s.ekle(olcum(0.0, 0.0, 0.0, 10.0))
        s.ekle(olcum(600.0, 3_000.0, 0.0, 10.0))
        assertEquals(3_000.0, s.toplamM.toDouble(), 2.0)
    }

    @Test fun sicramaYokSayilirCapaKorunur() {
        val s = KmSayaci()
        s.ekle(olcum(0.0, 0.0, 0.0, 10.0))
        assertEquals(0.0, s.ekle(olcum(1.0, 5_000.0, 0.0, 10.0)), 0.0)
        s.ekle(olcum(2.0, 20.0, 0.0, 10.0))
        assertEquals(20.0, s.toplamM.toDouble(), 2.0)
    }

    /** Hız ölçümü bozulursa (tek ölçümde 90 m/sn) konumdan hesaplanır. */
    @Test fun bozukHizdaKonum() {
        val s = KmSayaci()
        s.ekle(olcum(0.0, 0.0, 0.0, 10.0))
        s.ekle(olcum(1.0, 10.0, 0.0, 90.0))
        assertEquals(10.0, s.toplamM.toDouble(), 1.0)
    }

    @Test fun sahteAgVeKotuDogrulukKullanilmaz() {
        val s = KmSayaci()
        s.ekle(olcum(0.0, 0.0, 0.0, 10.0))
        assertEquals(0.0, s.ekle(olcum(1.0, 10.0, 0.0, 10.0).copy(sahte = true)), 0.0)
        assertEquals(0.0, s.ekle(olcum(2.0, 20.0, 0.0, 10.0).copy(kaynak = NoktaKaynagi.AG)), 0.0)
        assertEquals(0.0, s.ekle(olcum(3.0, 30.0, 0.0, 10.0, dog = 45.0)), 0.0)
        assertEquals(0L, s.toplamM)
    }

    @Test fun geriGidenZamanYokSayilir() {
        val s = KmSayaci()
        s.ekle(olcum(10.0, 0.0, 0.0, 10.0))
        assertEquals(0.0, s.ekle(olcum(5.0, 50.0, 0.0, 10.0)), 0.0)
    }

    /** Hizmet yeniden başlayınca toplam sürer; aradaki yol boşluk kuralıyla eklenir. */
    @Test fun saklanipYuklenince() {
        val a = KmSayaci()
        for (i in 0..100) a.ekle(olcum(i.toDouble(), 10.0 * i, 0.0, 10.0))
        val d = a.durum!!
        val b = KmSayaci()
        b.yukle(d)
        assertEquals(a.toplamM, b.toplamM)
        b.ekle(olcum(400.0, 1_000.0 + 2_000.0, 0.0, 10.0))
        assertEquals(3_000.0, b.toplamM.toDouble(), 5.0)
        // Bozuk saklama yüklenmez.
        val c = KmSayaci()
        c.yukle(d.copy(toplamM = Double.NaN))
        assertFalse(c.durum != null)
    }

    /** Gerçekçi gün: dur-kalk, kavşak dönüşleri, ölçüm başına ±3 m konum ve ±0,2 m/sn hız gürültüsü. */
    @Test fun gurultuluSehirIci() {
        val s = KmSayaci()
        val r = Random(11)
        var x = 0.0
        var y = 0.0
        var yon = 0.0
        var gercek = 0.0
        var t = 0
        repeat(40) { blok ->
            // 60 sn sür (6–14 m/sn), sonra kavşakta 90° dön, sonra 45 sn dur.
            val v = 6.0 + 8.0 * r.nextDouble()
            repeat(60) {
                x += v * cos(yon)
                y += v * sin(yon)
                gercek += v
                t++
                s.ekle(olcum(t.toDouble(), x + r.nextDouble(-3.0, 3.0), y + r.nextDouble(-3.0, 3.0), (v + r.nextDouble(-0.2, 0.2)).coerceAtLeast(0.0)))
            }
            yon += if (blok % 2 == 0) PI / 2 else -PI / 2
            repeat(45) {
                t++
                s.ekle(olcum(t.toDouble(), x + r.nextDouble(-6.0, 6.0), y + r.nextDouble(-6.0, 6.0), r.nextDouble(0.0, 0.35), 10.0))
            }
        }
        assertEquals(gercek, s.toplamM.toDouble(), gercek * 0.01)
    }
}

class GonderimVeKurulumTest {
    @Test fun depodaVeDururkenSeyrek() {
        assertEquals(600_000L, TakipAyari.gonderimMs(60, TerminalDurumu.DEPODA))
        assertEquals(300_000L, TakipAyari.gonderimMs(60, TerminalDurumu.DURGUN))
        assertEquals(60_000L, TakipAyari.gonderimMs(60, TerminalDurumu.HAREKET))
        // Merkezin aralığı daha uzunsa o geçerlidir.
        assertEquals(900_000L, TakipAyari.gonderimMs(900, TerminalDurumu.DEPODA))
        assertEquals(120_000L, TakipAyari.gonderimMs(120, TerminalDurumu.KAPALI))
    }

    @Test fun saniyelikGpsKarari() {
        assertTrue(OrneklemePolitikasi.sikGps(TerminalDurumu.HAREKET, 5, false))
        assertTrue(OrneklemePolitikasi.sikGps(TerminalDurumu.DURGUN, 30, false))
        assertFalse(OrneklemePolitikasi.sikGps(TerminalDurumu.DURGUN, 29, false))
        assertTrue(OrneklemePolitikasi.sikGps(TerminalDurumu.DURGUN, 10, true))
        assertFalse(OrneklemePolitikasi.sikGps(TerminalDurumu.DEPODA, 100, true))
        assertFalse(OrneklemePolitikasi.sikGps(TerminalDurumu.KAPALI, 100, true))
    }

    @Test fun kayitAraligindaIletilirHizlanincaErken() {
        // Hareket: 15 sn'lik kayıt, saniyelik ölçüm; hızlı olsa da erken iletilmez.
        assertFalse(OrneklemePolitikasi.iletilsinMi(10_000, 15_000, 12.0, erken = false))
        assertTrue(OrneklemePolitikasi.iletilsinMi(14_600, 15_000, 12.0, erken = false))
        // Dururken 120 sn'lik kayıt: araç hızlanınca 5 sn'den sonra beklemeden.
        assertFalse(OrneklemePolitikasi.iletilsinMi(30_000, 120_000, 0.3, erken = true))
        assertFalse(OrneklemePolitikasi.iletilsinMi(3_000, 120_000, 8.0, erken = true))
        assertTrue(OrneklemePolitikasi.iletilsinMi(6_000, 120_000, 8.0, erken = true))
        assertFalse(OrneklemePolitikasi.iletilsinMi(6_000, 120_000, null, erken = true))
        // Depoda (erken yok) seyrek kalır.
        assertFalse(OrneklemePolitikasi.iletilsinMi(6_000, 120_000, 8.0, erken = false))
    }

    @Test fun kurulumAyrintisi() {
        assertEquals("pil:1,arka:1", KurulumDurumu.ayrinti(true, true))
        assertEquals("pil:0,arka:1", KurulumDurumu.ayrinti(false, true))
        assertEquals("pil:1,arka:0", KurulumDurumu.ayrinti(true, false))
    }
}
