package com.bup.sanalpos.rota

/**
 * Firestore'a yazılan belgelerin saf karşılığı (sözleşme: ROTA_MIMARI §4, şema 1). Değerler
 * yalnız String/Long/Double/Boolean/null/List/Map ile [Zaman] ve [SunucuZamani]'dır; Android
 * tarafı (FirestoreYazici) bunları Timestamp ve FieldValue.serverTimestamp()'e çevirir.
 * Böylece belge biçimi Firebase olmadan sınanır ve docs/rota/sozlesme örnekleriyle karşılaştırılır.
 */
data class Zaman(val ms: Long)

object SunucuZamani

const val SEMA = 1L

/** Gönderilecek parça: kuyruğun başından alınmış, sırası boşluksuz kayıtlar. */
class Parca private constructor(val cihaz: String, val kayitlar: List<KuyrukKaydi>) {
    val ilk: Long get() = kayitlar.first().sira
    val son: Long get() = kayitlar.last().sira
    val kimlik: String get() = "${cihaz}_$ilk"
    val bas: Long get() = kayitlar.minOf { it.zaman }
    val bit: Long get() = kayitlar.maxOf { it.zaman }
    val noktaSayisi: Int get() = kayitlar.count { it is KuyrukKaydi.N }

    fun belge(cihazSaatiMs: Long, pil: Int, sarj: Boolean, surum: Long): Map<String, Any?> = linkedMapOf(
        "s" to SEMA,
        "cihaz" to cihaz,
        "ilk" to ilk,
        "son" to son,
        "bas" to Zaman(bas),
        "bit" to Zaman(bit),
        "alindi" to SunucuZamani,
        "silinme" to Zaman(bit + SAKLAMA_MS),
        "cihazSaati" to cihazSaatiMs,
        "pil" to pil.coerceIn(0, 100).toLong(),
        "sarj" to sarj,
        "surum" to surum,
        "n" to kayitlar.filterIsInstance<KuyrukKaydi.N>().map { noktaBelgesi(it.nokta) },
        "olaylar" to kayitlar.filterIsInstance<KuyrukKaydi.O>().map { olayBelgesi(it.olay) },
    )

    companion object {
        const val EN_COK_NOKTA = 240
        const val EN_COK_OLAY = 50
        const val SAKLAMA_MS = 90L * 24 * 3600 * 1000

        /**
         * Kuyruğun başından (sıraya göre dizili) en uzun boşluksuz öneki alır; nokta ve olay
         * sınırlarını aşmaz. Kayıt yoksa null. Boşluk (ör. kuyruk taşması sonrası) bir sonraki
         * parçanın başı olur; sunucu kuralı parça içinde boşluğa izin vermez.
         */
        fun olustur(cihaz: String, kuyrukBasi: List<KuyrukKaydi>): Parca? {
            require(cihaz.matches(Regex("^[A-Za-z0-9]{1,128}$"))) { "Geçersiz cihaz kimliği" }
            val secilen = ArrayList<KuyrukKaydi>()
            var nokta = 0
            var olay = 0
            for (k in kuyrukBasi) {
                if (secilen.isNotEmpty() && k.sira != secilen.last().sira + 1) break
                when (k) {
                    is KuyrukKaydi.N -> if (nokta == EN_COK_NOKTA) break else nokta++
                    is KuyrukKaydi.O -> if (olay == EN_COK_OLAY) break else olay++
                }
                secilen += k
            }
            return if (secilen.isEmpty()) null else Parca(cihaz, secilen)
        }

        fun noktaBelgesi(n: Nokta): Map<String, Any?> = linkedMapOf(
            "q" to n.sira,
            "z" to n.zaman,
            "en" to n.enlem,
            "boy" to n.boylam,
            "dog" to n.dogruluk,
            "hiz" to n.hiz,
            "yon" to n.yon,
            "yuk" to n.rakim,
            "kay" to n.kaynak.kod,
            "sahte" to n.sahte,
            "zayif" to n.zayif,
            "o" to n.km,
        )

        fun olayBelgesi(o: Olay): Map<String, Any?> = linkedMapOf<String, Any?>(
            "q" to o.sira,
            "z" to o.zaman,
            "tur" to o.tur.kod,
        ).apply { if (o.ayrinti != null) put("a", o.ayrinti) }
    }
}

/** rotaSonDurum/{uid}: canlı haritanın dinlediği tek belge. */
object DurumBelgesi {
    fun olustur(
        son: Nokta?,
        durum: TerminalDurumu,
        pil: Int,
        sarj: Boolean,
        bekleyen: Long,
        surum: Long,
    ): Map<String, Any?> = linkedMapOf(
        "s" to SEMA,
        "z" to son?.zaman,
        "en" to son?.enlem,
        "boy" to son?.boylam,
        "dog" to son?.dogruluk,
        "hiz" to son?.hiz?.coerceIn(0.0, 200.0),
        "yon" to son?.yon?.coerceIn(0.0, 360.0),
        "pil" to pil.coerceIn(0, 100).toLong(),
        "sarj" to sarj,
        "durum" to durum.kod,
        "bekleyen" to bekleyen.coerceIn(0, 10_000_000),
        "surum" to surum,
        "guncelleme" to SunucuZamani,
    )
}

/** rotaBasvurular/{uid}: onay bekleyen terminalin bir kez bıraktığı başvuru. */
object BasvuruBelgesi {
    fun olustur(uid: String, model: String, uretici: String, android: Int, surum: Long): Map<String, Any?> =
        linkedMapOf(
            "s" to SEMA,
            "kod" to TerminalKodu.uret(uid),
            "model" to temiz(model),
            "uretici" to temiz(uretici),
            "android" to android.toLong(),
            "surum" to surum,
            "olusturma" to SunucuZamani,
        )

    /** Kural: 1–60 karakter, denetim karakteri yok. */
    private fun temiz(s: String): String =
        s.filter { it.code >= 0x20 && it.code != 0x7f }.trim().take(60).ifEmpty { "bilinmiyor" }
}
