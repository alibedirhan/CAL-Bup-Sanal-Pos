package com.bup.sanalpos.rota

// Rota çekirdeğinin veri türleri (docs/ROTA_MIMARI.md §4). Bu paketteki saf dosyalar Android
// sınıfı kullanmaz: JVM birim testleriyle sınanır (android/app/src/test).

/** Noktanın kaynağı: uydu (GPS) veya ağ (baz/Wi-Fi). Sözleşmede tek harf. */
enum class NoktaKaynagi(val kod: String) { GPS("g"), AG("a") }

/** Kuyruktaki bir konum noktası. [sira] noktalar ve olaylar arasında ortaktır, boşluksuz artar. */
data class Nokta(
    val sira: Long,
    /** GPS zamanı (epoch ms). Ağ konumunda cihazın verdiği zaman. */
    val zaman: Long,
    val enlem: Double,
    val boylam: Double,
    /** Yatay doğruluk (m). */
    val dogruluk: Double,
    val hiz: Double?,
    val yon: Double?,
    val rakim: Double?,
    val kaynak: NoktaKaynagi,
    val sahte: Boolean,
) {
    /** Çok kötü doğruluk: gönderilir ama durum kararına katılmaz (M10). */
    val zayif: Boolean get() = dogruluk > ZAYIF_DOGRULUK_M

    companion object {
        const val ZAYIF_DOGRULUK_M = 500.0
    }
}

/** Merkeze bildirilen olay türleri. Kod adları sözleşmedir (firestore.rules değil, okuyucu denetler). */
enum class OlayTuru(val kod: String) {
    HIZMET_BASLADI("hizmet_basladi"),
    ACILIS("acilis"),
    KAPANIS("kapanis"),
    KONUM_KAPANDI("konum_kapandi"),
    KONUM_ACILDI("konum_acildi"),
    IZIN_YOK("izin_yok"),
    PIL_DUSUK("pil_dusuk"),
    SAAT_DEGISTI("saat_degisti"),
    SAHTE_KONUM("sahte_konum"),
    TAKIP_ACILDI("takip_acildi"),
    TAKIP_KAPANDI("takip_kapandi"),
    KUYRUK_TASTI("kuyruk_tasti"),
}

/** Kuyruktaki bir olay. [zaman] saat farkıyla düzeltilmiş cihaz saatidir (ROTA_MIMARI §5.6). */
data class Olay(val sira: Long, val zaman: Long, val tur: OlayTuru, val ayrinti: String? = null) {
    init {
        require(ayrinti == null || ayrinti.length <= AYRINTI_EN_COK) { "Olay ayrıntısı çok uzun" }
    }

    companion object {
        const val AYRINTI_EN_COK = 80
    }
}

/** Kuyruk kaydı: ya nokta ya olay. Sıra numarası ortak. */
sealed interface KuyrukKaydi {
    val sira: Long
    val zaman: Long

    data class N(val nokta: Nokta) : KuyrukKaydi {
        override val sira get() = nokta.sira
        override val zaman get() = nokta.zaman
    }

    data class O(val olay: Olay) : KuyrukKaydi {
        override val sira get() = olay.sira
        override val zaman get() = olay.zaman
    }
}

/** Terminalin merkeze bildirdiği durum (rotaSonDurum.durum). */
enum class TerminalDurumu(val kod: String) {
    HAREKET("hareket"),
    DURGUN("durgun"),
    DEPODA("depoda"),
    KAPALI("kapali"),
    IZIN_YOK("izin_yok"),
    KONUM_KAPALI("konum_kapali"),
    ONAY_BEKLIYOR("onay_bekliyor"),
}

/** Merkezden gelen takip ayarı (rotaCihazlar/{uid}). */
data class TakipAyari(
    val aktif: Boolean,
    val takip: Boolean,
    val hareketSn: Int,
    val durgunSn: Int,
    val depoSn: Int,
    /** Sunucuya en sık bu kadar saniyede bir yazılır (K31, ücretsiz kota); noktalar yine [hareketSn]'de alınır. */
    val gonderimSn: Int = VARSAYILAN_GONDERIM_SN,
) {
    val calisir: Boolean get() = aktif && takip

    companion object {
        /** Onay gelmeden ve belge okunamazken: konum alınmaz. */
        val KAPALI = TakipAyari(aktif = false, takip = false, hareketSn = 15, durgunSn = 120, depoSn = 300)

        /** Sunucudan gelen değerleri doğrular; bozuk değer güvenli varsayılana döner. */
        /** K31: 2 dakika. Alan merkezde yoksa (0.13.0 dönemi belgeleri) de bu geçerlidir. */
        const val VARSAYILAN_GONDERIM_SN = 120

        fun guvenli(aktif: Any?, takip: Any?, hareketSn: Any?, durgunSn: Any?, depoSn: Any?, gonderimSn: Any? = null): TakipAyari {
            fun sn(x: Any?, varsayilan: Int, en: Long = 5L) = (x as? Number)?.toLong()?.takeIf { it in en..3600L }?.toInt() ?: varsayilan
            return TakipAyari(
                aktif = aktif == true,
                takip = takip == true,
                hareketSn = sn(hareketSn, KAPALI.hareketSn),
                durgunSn = sn(durgunSn, KAPALI.durgunSn),
                depoSn = sn(depoSn, KAPALI.depoSn),
                // Sunucunun hız sınırı 15 sn (kural da 15–3600 ister).
                gonderimSn = sn(gonderimSn, VARSAYILAN_GONDERIM_SN, en = 15L),
            )
        }
    }
}

/** Depo bölgesi (rotaAyar/genel.depolar). */
data class Depo(val ad: String, val enlem: Double, val boylam: Double, val yaricap: Double) {
    companion object {
        /** Sunucudan gelen listeyi doğrular; bozuk öğe atlanır (okuyan taraf güvenmez, M14). */
        fun listeden(ham: Any?): List<Depo> = (ham as? List<*>).orEmpty().mapNotNull { o ->
            val m = o as? Map<*, *> ?: return@mapNotNull null
            val en = (m["en"] as? Number)?.toDouble() ?: return@mapNotNull null
            val boy = (m["boy"] as? Number)?.toDouble() ?: return@mapNotNull null
            val r = (m["yaricap"] as? Number)?.toDouble() ?: return@mapNotNull null
            if (en !in -90.0..90.0 || boy !in -180.0..180.0 || r !in 10.0..5000.0) return@mapNotNull null
            Depo((m["ad"] as? String)?.take(40) ?: "Depo", en, boy, r)
        }.take(10)
    }
}
