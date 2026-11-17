package com.bup.sanalpos.rota

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Gönderici (ROTA_MIMARI §5 adım 3–4): kayıp yok, çift yok, hız sınırı, geri çekilme. */
class GondericiTest {
    private val uid = "cihaz1"
    private val anlik = Anlik(1_763_366_480_000, 80, false, 23)

    private class BellekKuyrugu : KuyrukDeposu {
        val kayitlar = sortedMapOf<Long, KuyrukKaydi>()
        private var sira = 0L
        fun nokta(z: Long = 1_763_366_400_000) {
            val n = nokta(++sira, z)
            kayitlar[n.sira] = KuyrukKaydi.N(n)
        }
        override fun bas(adet: Int) = kayitlar.values.take(adet)
        override fun sil(ilk: Long, son: Long): Int {
            val k = kayitlar.keys.filter { it in ilk..son }
            k.forEach { kayitlar.remove(it) }
            return k.size
        }
        override fun sayi() = kayitlar.size.toLong()
    }

    /** Sunucu taklidi: kabul edilen parçaları kimlikle tutar; istenen yanıtları sırayla verir. */
    private class TaklitSunucu : RotaSunucusu {
        val parcalar = linkedMapOf<String, Map<String, Any?>>()
        val durumlar = mutableListOf<Map<String, Any?>>()
        val yanitlar = ArrayDeque<GonderimSonucu>()
        var gonderimSayisi = 0
        override fun gonder(kimlik: String, parca: Map<String, Any?>, durum: Map<String, Any?>): GonderimYaniti {
            gonderimSayisi++
            if (kimlik in parcalar) return GonderimYaniti(GonderimSonucu.ZATEN_VAR, parcalar[kimlik]!!["son"] as Long)
            val y = yanitlar.removeFirstOrNull() ?: GonderimSonucu.TAMAM
            // "Belirsiz": yazma sunucuya ulaştı ama yanıt gelmedi.
            if (y == GonderimSonucu.TAMAM || y == BELIRSIZ) {
                parcalar[kimlik] = parca
                durumlar += durum
            }
            return GonderimYaniti(if (y == BELIRSIZ) GonderimSonucu.GECICI else y)
        }
        override fun durumYaz(durum: Map<String, Any?>): GonderimSonucu {
            val y = yanitlar.removeFirstOrNull() ?: GonderimSonucu.TAMAM
            if (y == GonderimSonucu.TAMAM) durumlar += durum
            return y
        }
    }

    private companion object {
        /** Taklit yanıt: ZATEN_VAR'ı belirsizlik işareti olarak kullanır (gerçekte dönmez). */
        val BELIRSIZ = GonderimSonucu.ZATEN_VAR
    }

    private fun durumBelgesi(kod: String) = { bekleyen: Long -> mapOf("durum" to kod, "bekleyen" to bekleyen) }

    @Test fun birikmisKuyrukHizSinirinaUyarakBosalir() {
        val k = BellekKuyrugu()
        repeat(600) { k.nokta() }
        val s = TaklitSunucu()
        val g = Gonderici(uid, k, s)
        var t = 0L
        var adim = 0
        while (k.sayi() > 0 && adim++ < 100) {
            val r = g.calis(t, anlik, "hareket", durumBelgesi("hareket"))
            if (r.sonuc != null) assertTrue(r.sonrakiMs >= Gonderici.EN_AZ_ARALIK_MS)
            t += r.sonrakiMs
        }
        assertEquals(0L, k.sayi())
        assertEquals(listOf("${uid}_1", "${uid}_241", "${uid}_481"), s.parcalar.keys.toList())
        assertEquals(listOf(360L, 120L, 0L), s.durumlar.map { it["bekleyen"] })
    }

    @Test fun hizSiniriIcindeIkinciYazmaYapilmaz() {
        val k = BellekKuyrugu()
        repeat(300) { k.nokta() }
        val s = TaklitSunucu()
        val g = Gonderici(uid, k, s)
        g.calis(0, anlik, "hareket", durumBelgesi("hareket"))
        val r = g.calis(5_000, anlik, "hareket", durumBelgesi("hareket"))
        assertNull(r.sonuc)
        assertEquals(11_000L, r.sonrakiMs)
        assertEquals(1, s.gonderimSayisi)
    }

    @Test fun belirsizGonderimdenSonraCiftYokKayipYok() {
        val k = BellekKuyrugu()
        repeat(3) { k.nokta() }
        val s = TaklitSunucu().apply { yanitlar += BELIRSIZ }
        val g = Gonderici(uid, k, s)
        val r1 = g.calis(0, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.GECICI, r1.sonuc)
        // Bu arada yeni noktalar geldi: yeniden kurulan parça (ilk=1) artık 5 kayıt.
        repeat(2) { k.nokta() }
        val r2 = g.calis(r1.sonrakiMs, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.ZATEN_VAR, r2.sonuc)
        // Yalnız sunucudaki 1–3 silindi; 4–5 kuyrukta kaldı ve yeni kimlikle gider.
        assertEquals(listOf(4L, 5L), k.kayitlar.keys.toList())
        val r3 = g.calis(r1.sonrakiMs + r2.sonrakiMs, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.TAMAM, r3.sonuc)
        assertEquals(listOf("${uid}_1", "${uid}_4"), s.parcalar.keys.toList())
        assertEquals(listOf(3L, 5L), s.parcalar.values.map { it["son"] })
        assertEquals(0L, k.sayi())
    }

    @Test fun hatadaKayitKalirGeriCekilerekYenidenDenenir() {
        val k = BellekKuyrugu()
        repeat(3) { k.nokta() }
        val s = TaklitSunucu().apply { yanitlar += listOf(GonderimSonucu.GECICI, GonderimSonucu.GECICI) }
        val g = Gonderici(uid, k, s)
        val r1 = g.calis(0, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.GECICI, r1.sonuc)
        assertEquals(3L, k.sayi())
        val r2 = g.calis(r1.sonrakiMs, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.GECICI, r2.sonuc)
        val r3 = g.calis(r1.sonrakiMs + r2.sonrakiMs, anlik, "hareket", durumBelgesi("hareket"))
        assertEquals(GonderimSonucu.TAMAM, r3.sonuc)
        assertEquals(0L, k.sayi())
        assertEquals(listOf("${uid}_1"), s.parcalar.keys.toList())
    }

    @Test fun bosKuyruktaDurumYalnizDegisinceYazilir() {
        val s = TaklitSunucu()
        val g = Gonderici(uid, BellekKuyrugu(), s)
        g.calis(0, anlik, "onay_bekliyor", durumBelgesi("onay_bekliyor"))
        val r = g.calis(60_000, anlik, "onay_bekliyor", durumBelgesi("onay_bekliyor"))
        assertNull(r.sonuc)
        g.calis(120_000, anlik, "izin_yok", durumBelgesi("izin_yok"))
        assertEquals(listOf("onay_bekliyor", "izin_yok"), s.durumlar.map { it["durum"] })
    }

    @Test fun surekliRetteAradaDurumYazilirGeriCekilmeSifirlanmaz() {
        val k = BellekKuyrugu()
        repeat(3) { k.nokta() }
        // Parçalar hep reddedilir (ör. bozuk parça), durum yazımları kabul edilir.
        val durumlar = mutableListOf<Map<String, Any?>>()
        var parcaDenemesi = 0
        val sunucu = object : RotaSunucusu {
            override fun gonder(kimlik: String, parca: Map<String, Any?>, durum: Map<String, Any?>) =
                GonderimYaniti(GonderimSonucu.REDDEDILDI).also { parcaDenemesi++ }
            override fun durumYaz(durum: Map<String, Any?>) = GonderimSonucu.TAMAM.also { durumlar += durum }
        }
        val g = Gonderici(uid, k, sunucu)
        var t = 0L
        val bekleyisler = mutableListOf<Long>()
        while (t < 6 * 3600_000L) {
            val r = g.calis(t, anlik, "hareket", durumBelgesi("hareket"))
            bekleyisler += r.sonrakiMs
            t += r.sonrakiMs
        }
        assertEquals(3L, k.sayi())
        assertTrue("Ret sürerken merkeze durum gitmeli", durumlar.isNotEmpty())
        assertEquals(3L, durumlar.first()["bekleyen"])
        // Geri çekilme büyür ve 15 dk'da durur: 6 saatte parça denemesi sınırlı kalır.
        assertEquals(15 * 60_000L, bekleyisler.max())
        assertTrue("Parça denemesi: $parcaDenemesi", parcaDenemesi in 20..40)
    }
}
