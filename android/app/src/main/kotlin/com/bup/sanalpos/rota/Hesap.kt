package com.bup.sanalpos.rota

import java.security.MessageDigest
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** İki konum arası yer yüzeyi mesafesi (haversine, metre). */
object Mesafe {
    private const val DUNYA_YARICAPI_M = 6_371_008.8

    fun metre(en1: Double, boy1: Double, en2: Double, boy2: Double): Double {
        val r = Math.PI / 180
        val dEn = (en2 - en1) * r
        val dBoy = (boy2 - boy1) * r
        val a = sin(dEn / 2) * sin(dEn / 2) + cos(en1 * r) * cos(en2 * r) * sin(dBoy / 2) * sin(dBoy / 2)
        return 2 * DUNYA_YARICAPI_M * asin(min(1.0, sqrt(a)))
    }
}

/**
 * Kurulum ekranında ve CAL_bup onay listesinde görünen 6 karakterlik terminal kodu (M3).
 * Anonim kimlikten türetilir: aynı kimlik hep aynı kodu verir. Karışan harfler (I, O, 0, 1) yok;
 * alfabe firestore.rules'daki `[A-HJ-NP-Z2-9]` ile aynıdır.
 */
object TerminalKodu {
    const val ALFABE = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    fun uret(uid: String): String {
        require(uid.isNotBlank()) { "Kimlik boş" }
        val ozet = MessageDigest.getInstance("SHA-256").digest(uid.toByteArray(Charsets.UTF_8))
        // 32 harfli alfabe: her karakter 5 bit; ilk 30 bit kullanılır.
        var bitler = 0L
        for (i in 0 until 4) bitler = (bitler shl 8) or (ozet[i].toLong() and 0xff)
        return buildString {
            for (i in 0 until 6) append(ALFABE[((bitler shr (27 - 5 * i)) and 31).toInt()])
        }
    }
}

/**
 * Gönderim hatasından sonra bekleme: 1, 2, 4, 8 … sn, en çok 15 dk. Başarıda sıfırlanır.
 * Saf: zaman dışarıdan verilir.
 */
class GeriCekilme(private val ilkMs: Long = 1_000, private val enCokMs: Long = 15 * 60_000) {
    private var ardisikHata = 0
    private var sonrakiDenemeMs = 0L

    val hataSayisi: Int get() = ardisikHata

    fun basarili() {
        ardisikHata = 0
        sonrakiDenemeMs = 0
    }

    fun basarisiz(simdiMs: Long) {
        ardisikHata++
        val bekleme = if (ardisikHata >= 31) enCokMs else min(enCokMs, ilkMs shl (ardisikHata - 1))
        sonrakiDenemeMs = simdiMs + bekleme
    }

    fun denenebilir(simdiMs: Long): Boolean = simdiMs >= sonrakiDenemeMs

    fun beklenecekMs(simdiMs: Long): Long = (sonrakiDenemeMs - simdiMs).coerceAtLeast(0)
}

/**
 * Gerçek zaman tahmini (ROTA_MIMARI §5.6, M21). Cihazın duvar saatine güvenilmez: elle ileri/geri alınabilir.
 * Son güvenilir zaman (GPS uydusu) **tekdüze saatle** (açılıştan beri geçen süre; elle değiştirilemez)
 * birlikte tutulur: `gerçek(şimdi) = gpsZamanı + (tekdüze(şimdi) − tekdüze(gps anı))`. Böylece cihaz saati
 * GPS'ten *sonra* değiştirilse de olay ve ağ konumu zamanları kaymaz. Tekdüze saat yeniden başlatmada
 * sıfırlanır: referans açılış sayısıyla birlikte saklanır ([Referans.acilis]), başka açılışta geçersizdir.
 * GPS yokken (yeniden başlatmadan sonra kapalı alanda) ağ saati (Android 13+), o da yoksa cihaz saati kullanılır.
 */
class SaatFarki {
    data class Referans(val gercekMs: Long, val tekduzeMs: Long, val acilis: Int)

    @Volatile var referans: Referans? = null
        private set

    /** Saklanmış referansı yükler; başka açılışa aitse yok sayılır. */
    fun yukle(r: Referans?, acilis: Int) {
        if (r != null && r.acilis == acilis && referans == null) referans = r
    }

    /** Yalnız uydu (GPS) zamanı güvenilirdir; ağ konumunun zamanı cihaz saatidir. */
    fun gpsGeldi(gpsZamaniMs: Long, tekduzeMs: Long, acilis: Int) {
        referans = Referans(gpsZamaniMs, tekduzeMs, acilis)
    }

    /** Şimdiki gerçek zaman tahmini. [agSaatiMs] ağ saati (yoksa null). */
    fun simdi(cihazSaatiMs: Long, tekduzeMs: Long, agSaatiMs: Long? = null): Long =
        referans?.let { it.gercekMs + (tekduzeMs - it.tekduzeMs) } ?: agSaatiMs ?: cihazSaatiMs

    /** Cihaz saatiyle alınmış geçmiş bir zamanı ([cihazZamaniMs]) aynı yaşla gerçek zamana taşır. */
    fun duzelt(cihazZamaniMs: Long, cihazSaatiMs: Long, tekduzeMs: Long, agSaatiMs: Long? = null): Long =
        simdi(cihazSaatiMs, tekduzeMs, agSaatiMs) - (cihazSaatiMs - cihazZamaniMs)

    /** Cihaz saatinin gerçek zamandan farkı (− ileri, + geri). */
    fun fark(cihazSaatiMs: Long, tekduzeMs: Long, agSaatiMs: Long? = null): Long =
        simdi(cihazSaatiMs, tekduzeMs, agSaatiMs) - cihazSaatiMs
}
