package com.bup.sanalpos.rota

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class TerminalKoduTest {
    @Test fun ayniKimlikAyniKod() {
        assertEquals(TerminalKodu.uret("abc123"), TerminalKodu.uret("abc123"))
    }

    @Test fun kodKuralBicimine_uyar() {
        val kural = Regex("^[A-HJ-NP-Z2-9]{6}$") // firestore.rules rotaBasvurular.kod
        repeat(2000) { assertTrue(kural.matches(TerminalKodu.uret("uid$it"))) }
    }

    @Test fun algoritmaSabittir() {
        // Bu değer değişirse kurulmuş terminallerin kodu değişir: algoritmayı değiştirmeyin.
        assertEquals("K9WMEY", TerminalKodu.uret("terminalBir0000000000000001"))
    }

    @Test fun kodlarDagilir() {
        val kodlar = (0 until 1000).map { TerminalKodu.uret("terminal-$it") }.toSet()
        assertTrue(kodlar.size >= 998)
    }
}

class MesafeTest {
    @Test fun ekvatordaBirDerece() {
        assertEquals(111_195.0, Mesafe.metre(0.0, 0.0, 0.0, 1.0), 1.0)
    }

    @Test fun ayniNoktaSifir() {
        assertEquals(0.0, Mesafe.metre(38.46, 27.22, 38.46, 27.22), 1e-9)
    }

    @Test fun kisaMesafe() {
        // 0,001° enlem ≈ 111 m.
        assertEquals(111.2, Mesafe.metre(38.46, 27.22, 38.461, 27.22), 0.5)
    }
}

class GeriCekilmeTest {
    @Test fun ustelArtarVeSinirlanir() {
        val g = GeriCekilme()
        assertTrue(g.denenebilir(0))
        val beklemeler = (1..15).map { i ->
            g.basarisiz(1_000_000L * i)
            var t = 1_000_000L * i
            while (!g.denenebilir(t)) t += 1_000
            t - 1_000_000L * i
        }
        assertEquals(listOf(1_000L, 2_000L, 4_000L, 8_000L), beklemeler.take(4))
        assertEquals(15 * 60_000L, beklemeler.last())
        g.basarili()
        assertTrue(g.denenebilir(0))
        assertEquals(0, g.hataSayisi)
    }

    @Test fun cokSayidaHataTasmaz() {
        val g = GeriCekilme()
        repeat(100) { g.basarisiz(0) }
        assertFalse(g.denenebilir(15 * 60_000L - 1))
        assertTrue(g.denenebilir(15 * 60_000L))
    }
}

class SaatFarkiTest {
    private val ileri = 7_200_000L // cihaz saati 2 saat ileri

    @Test fun gpsYokkenAgSaatiYoksaCihazSaati() {
        val s = SaatFarki()
        assertEquals(5_000L, s.simdi(cihazSaatiMs = 5_000L, tekduzeMs = 10L))
        assertEquals(4_000L, s.simdi(cihazSaatiMs = 5_000L, tekduzeMs = 10L, agSaatiMs = 4_000L))
    }

    @Test fun gpsSonrasiZamanTekduzeSaattenYurur() {
        val s = SaatFarki()
        s.gpsGeldi(gpsZamaniMs = 1_000_000L, tekduzeMs = 50_000L, acilis = 7)
        // 500 ms sonra; cihaz saati 2 saat ileri, ağ saati de yanlış olsa GPS esastır.
        assertEquals(1_000_500L, s.simdi(1_000_500L + ileri, 50_500L, agSaatiMs = 1L))
        assertEquals(-ileri, s.fark(1_000_500L + ileri, 50_500L))
    }

    @Test fun cihazSaatiGpsdenSonraDegistirilseDeKaymaz() {
        // Eski hata: fark GPS anında ölçülüp sabit tutuluyordu; saat sonradan ileri alınınca olay zamanları
        // da ileri kayıyor, GPS gelmeyen kapalı alanda parça sunucunun "gelecek" sınırına takılıyordu.
        val s = SaatFarki()
        s.gpsGeldi(gpsZamaniMs = 1_000_000L, tekduzeMs = 50_000L, acilis = 7)
        val birDkSonra = s.simdi(cihazSaatiMs = 1_060_000L + ileri, tekduzeMs = 110_000L)
        assertEquals(1_060_000L, birDkSonra)
    }

    @Test fun agKonumuZamaniAyniYaslaTasinir() {
        val s = SaatFarki()
        s.gpsGeldi(gpsZamaniMs = 1_000_000L, tekduzeMs = 50_000L, acilis = 7)
        // Konum 3 sn önce, ileri saatle damgalanmış.
        assertEquals(1_007_000L, s.duzelt(1_007_000L + ileri, 1_010_000L + ileri, 60_000L))
    }

    @Test fun saklanmisReferansYalnizAyniAcilistaGecerli() {
        val r = SaatFarki.Referans(gercekMs = 1_000_000L, tekduzeMs = 50_000L, acilis = 7)
        val ayni = SaatFarki().apply { yukle(r, acilis = 7) }
        assertEquals(1_010_000L, ayni.simdi(cihazSaatiMs = 9L, tekduzeMs = 60_000L))
        val yeniAcilis = SaatFarki().apply { yukle(r, acilis = 8) }
        assertEquals(9L, yeniAcilis.simdi(cihazSaatiMs = 9L, tekduzeMs = 60_000L))
        val yeni = SaatFarki().apply { gpsGeldi(2_000_000L, 1L, 7) }
        yeni.yukle(r, acilis = 7)
        assertEquals("Taze GPS, saklanmış referansla ezilmez", 2_000_000L, yeni.simdi(0L, 1L))
    }
}

class AyarTest {
    @Test fun bozukAyarGuvenliVarsayilanaDoner() {
        val a = TakipAyari.guvenli(aktif = "evet", takip = true, hareketSn = 1, durgunSn = 99999, depoSn = "x")
        assertFalse(a.aktif)
        assertFalse(a.calisir)
        assertEquals(TakipAyari.KAPALI.hareketSn, a.hareketSn)
        assertEquals(TakipAyari.KAPALI.durgunSn, a.durgunSn)
        assertEquals(TakipAyari.KAPALI.depoSn, a.depoSn)
    }

    @Test fun gecerliAyarAynenAlinir() {
        val a = TakipAyari.guvenli(true, true, 20L, 180L, 600.0)
        assertEquals(TakipAyari(true, true, 20, 180, 600), a)
        assertTrue(a.calisir)
    }

    @Test fun gonderimAraligiYoksaVeyaBozuksaIkiDakika() {
        assertEquals(120, TakipAyari.guvenli(true, true, 15, 120, 300).gonderimSn)
        assertEquals(120, TakipAyari.guvenli(true, true, 15, 120, 300, 14).gonderimSn)
        assertEquals(120, TakipAyari.guvenli(true, true, 15, 120, 300, "60").gonderimSn)
        assertEquals(120, TakipAyari.guvenli(true, true, 15, 120, 300, 3601L).gonderimSn)
        assertEquals(15, TakipAyari.guvenli(true, true, 15, 120, 300, 15L).gonderimSn)
        assertEquals(300, TakipAyari.guvenli(true, true, 15, 120, 300, 300.0).gonderimSn)
        assertEquals(120, TakipAyari.KAPALI.gonderimSn)
    }

    @Test fun depoListesiDogrulanir() {
        val ham = listOf(
            mapOf("ad" to "Bornova", "en" to 38.46, "boy" to 27.22, "yaricap" to 150),
            mapOf("en" to 95.0, "boy" to 27.0, "yaricap" to 150),
            mapOf("en" to 38.0, "boy" to 27.0, "yaricap" to 1),
            "bozuk",
            mapOf("en" to 38.1, "boy" to 27.1, "yaricap" to 200.0),
        )
        val d = Depo.listeden(ham)
        assertEquals(listOf("Bornova", "Depo"), d.map { it.ad })
        assertTrue(Depo.listeden(null).isEmpty())
        assertTrue(Depo.listeden("x").isEmpty())
    }
}

internal fun nokta(
    sira: Long,
    zaman: Long,
    en: Double = 38.40,
    boy: Double = 27.10,
    dog: Double = 5.0,
    hiz: Double? = 0.0,
) = Nokta(sira, zaman, en, boy, dog, hiz, null, null, NoktaKaynagi.GPS, sahte = false)

class OrneklemePolitikasiTest {
    private val ayar = TakipAyari(true, true, hareketSn = 15, durgunSn = 120, depoSn = 300)
    private val depo = Depo("Depo", 38.4600, 27.2200, 150.0)

    @Test fun ilkNoktaHareketSayilir() {
        val p = OrneklemePolitikasi(ayar)
        assertEquals(OrneklemePolitikasi.Karar(TerminalDurumu.HAREKET, 15), p.degerlendir(nokta(1, 0)))
    }

    @Test fun ucDakikaKimildamayanDurgunOlurHareketleHemenDoner() {
        val p = OrneklemePolitikasi(ayar)
        p.degerlendir(nokta(1, 0))
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(2, 170_000, en = 38.4003)).durum)
        val durgun = p.degerlendir(nokta(3, 180_000, en = 38.4002))
        assertEquals(OrneklemePolitikasi.Karar(TerminalDurumu.DURGUN, 120), durgun)
        // Hız 2 m/s üstü: hemen hareket.
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(4, 300_000, hiz = 8.0)).durum)
    }

    @Test fun hizBildirilmeseUzaklasmaHareketSayilir() {
        val p = OrneklemePolitikasi(ayar)
        p.degerlendir(nokta(1, 0, hiz = null))
        p.degerlendir(nokta(2, 200_000, hiz = null))
        assertEquals(TerminalDurumu.DURGUN, p.simdikiKarar.durum)
        // ~111 m kuzey: eşik 75 m.
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(3, 210_000, en = 38.401, hiz = null)).durum)
    }

    @Test fun kotuDogruluktaTitremeHareketSayilmaz() {
        val p = OrneklemePolitikasi(ayar)
        p.degerlendir(nokta(1, 0, dog = 60.0))
        // 111 m sapma ama doğruluk 60 m → eşik 120 m.
        p.degerlendir(nokta(2, 200_000, en = 38.401, dog = 60.0))
        assertEquals(TerminalDurumu.DURGUN, p.simdikiKarar.durum)
    }

    @Test fun zayifNoktaDurumuDegistirmez() {
        val p = OrneklemePolitikasi(ayar)
        p.degerlendir(nokta(1, 0))
        p.degerlendir(nokta(2, 200_000))
        assertEquals(TerminalDurumu.DURGUN, p.simdikiKarar.durum)
        val k = p.degerlendir(nokta(3, 210_000, en = 38.5, dog = 900.0, hiz = 30.0))
        assertEquals(TerminalDurumu.DURGUN, k.durum)
    }

    @Test fun depoyaGirisIkiNoktaIsterCikisPayliOlur() {
        val p = OrneklemePolitikasi(ayar, listOf(depo))
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(1, 0, en = 38.4605, boy = 27.2200, hiz = 3.0)).durum)
        val k = p.degerlendir(nokta(2, 15_000, en = 38.4602, boy = 27.2200))
        assertEquals(OrneklemePolitikasi.Karar(TerminalDurumu.DEPODA, 300), k)
        // Yarıçapın hemen dışı (~170 m) ama çıkış payı içinde: depoda kalır.
        assertEquals(TerminalDurumu.DEPODA, p.degerlendir(nokta(3, 30_000, en = 38.46153, boy = 27.2200, hiz = 3.0)).durum)
        // ~330 m: çıktı.
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(4, 45_000, en = 38.4630, boy = 27.2200, hiz = 3.0)).durum)
    }

    @Test fun depoIcindenTekNoktaYetmez() {
        val p = OrneklemePolitikasi(ayar, listOf(depo))
        p.degerlendir(nokta(1, 0, en = 38.4600, boy = 27.2200, hiz = 5.0))
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(2, 15_000, en = 38.4700, hiz = 5.0)).durum)
        assertEquals(TerminalDurumu.HAREKET, p.degerlendir(nokta(3, 30_000, en = 38.4600, boy = 27.2200, hiz = 5.0)).durum)
    }

    @Test fun ayarDegisinceAralikDegisir() {
        val p = OrneklemePolitikasi(ayar)
        p.degerlendir(nokta(1, 0))
        p.ayarla(ayar.copy(hareketSn = 30), emptyList())
        assertEquals(30, p.simdikiKarar.aralikSn)
    }
}

class ParcaTest {
    private val uid = "terminalBir0000000000000001"

    private fun kayitlar(vararg siralar: Long) = siralar.map { KuyrukKaydi.N(nokta(it, 1_700_000_000_000 + it * 15_000)) }

    @Test fun bosKuyruktaParcaYok() {
        assertNull(Parca.olustur(uid, emptyList()))
    }

    @Test fun bosluktaDurur() {
        val p = Parca.olustur(uid, kayitlar(5, 6, 7, 9, 10))!!
        assertEquals(5L, p.ilk)
        assertEquals(7L, p.son)
        assertEquals("${uid}_5", p.kimlik)
    }

    @Test fun noktaSiniri240() {
        val p = Parca.olustur(uid, kayitlar(*LongArray(300) { it + 1L }))!!
        assertEquals(240, p.noktaSayisi)
        assertEquals(240L, p.son)
    }

    @Test fun olaySiniri50SiraBoslugunaYolAcmaz() {
        val k = (1L..60L).map { KuyrukKaydi.O(Olay(it, 1_700_000_000_000 + it, OlayTuru.KONUM_KAPANDI)) } +
            KuyrukKaydi.N(nokta(61, 1_700_000_000_100))
        val p = Parca.olustur(uid, k)!!
        assertEquals(50L, p.son)
        // Sunucu kuralı: son − ilk + 1 = nokta + olay.
        val b = p.belge(0, 50, false, 23)
        assertEquals(p.son - p.ilk + 1, ((b["n"] as List<*>).size + (b["olaylar"] as List<*>).size).toLong())
    }

    @Test fun basBitVeSilinme() {
        val k = listOf(
            KuyrukKaydi.N(nokta(1, 2_000)),
            KuyrukKaydi.O(Olay(2, 1_000, OlayTuru.ACILIS)),
            KuyrukKaydi.N(nokta(3, 3_000)),
        )
        val b = Parca.olustur(uid, k)!!.belge(9, 50, true, 23)
        assertEquals(Zaman(1_000), b["bas"])
        assertEquals(Zaman(3_000), b["bit"])
        assertEquals(Zaman(3_000 + Parca.SAKLAMA_MS), b["silinme"])
        assertEquals(SunucuZamani, b["alindi"])
    }

    @Test fun gecersizCihazKimligiReddedilir() {
        val hata = runCatching { Parca.olustur("a_b", kayitlar(1)) }.exceptionOrNull()
        assertTrue(hata is IllegalArgumentException)
    }

    @Test fun durumBelgesiSinirlariKorur() {
        val b = DurumBelgesi.olustur(nokta(1, 5, hiz = 250.0), TerminalDurumu.HAREKET, 140, false, -3, 23)
        assertEquals(200.0, b["hiz"])
        assertEquals(100L, b["pil"])
        assertEquals(0L, b["bekleyen"])
        val bos = DurumBelgesi.olustur(null, TerminalDurumu.IZIN_YOK, 50, true, 0, 23)
        assertNull(bos["en"])
        assertEquals(13, bos.size)
    }

    @Test fun basvuruBelgesiTemizlenir() {
        val b = BasvuruBelgesi.olustur(uid, "TC15\u0000\n", "  ", 33, 23)
        assertEquals("TC15", b["model"])
        assertEquals("bilinmiyor", b["uretici"])
        assertEquals(7, b.size)
    }
}

class SozlesmeTest {
    /** docs/rota/sozlesme/parca-ornek.json: CAL_bup okuyucusu aynı örnekle sınanır (M11 / §7). */
    @Test fun parcaBelgesiOrnekleAyni() {
        val uid = "terminalBir0000000000000001"
        val k = listOf(
            KuyrukKaydi.N(Nokta(41, 1_763_366_400_000, 38.4612345, 27.2198765, 4.5, 11.25, 87.5, 41.0, NoktaKaynagi.GPS, false, km = 18_250)),
            KuyrukKaydi.O(Olay(42, 1_763_366_405_000, OlayTuru.KONUM_KAPANDI)),
            KuyrukKaydi.O(Olay(43, 1_763_366_465_000, OlayTuru.KURULUM, KurulumDurumu.ayrinti(pilMuaf = false, arkaPlanIzni = true))),
            KuyrukKaydi.N(Nokta(44, 1_763_366_470_000, 38.4613, 27.22, 650.0, null, null, null, NoktaKaynagi.AG, true)),
        )
        val belge = Parca.olustur(uid, k)!!.belge(1_763_366_480_000, 77, false, 26)
        val beklenen = java.io.File("../../docs/rota/sozlesme/parca-ornek.json").readText()
        assertEquals(sikistir(beklenen), Json.yaz(belge))
    }

    private fun sikistir(s: String): String {
        val b = StringBuilder()
        var tirnak = false
        for (c in s) {
            if (c == '"') tirnak = !tirnak
            if (tirnak || !c.isWhitespace()) b.append(c)
        }
        return b.toString()
    }
}

/** Sözleşme karşılaştırması için en küçük JSON yazıcısı (sıra korunur). */
internal object Json {
    fun yaz(x: Any?): String = when (x) {
        null -> "null"
        is String -> "\"" + x.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
        is Boolean, is Long, is Int -> x.toString()
        is Double -> if (x == Math.floor(x) && abs(x) < 1e15) x.toLong().toString() + ".0" else x.toString()
        is Zaman -> "{\"zaman\":${x.ms}}"
        SunucuZamani -> "\"<sunucu>\""
        is Map<*, *> -> x.entries.joinToString(",", "{", "}") { yaz(it.key.toString()) + ":" + yaz(it.value) }
        is List<*> -> x.joinToString(",", "[", "]") { yaz(it) }
        else -> error("Sözleşmede olmayan tür: ${x::class}")
    }
}
