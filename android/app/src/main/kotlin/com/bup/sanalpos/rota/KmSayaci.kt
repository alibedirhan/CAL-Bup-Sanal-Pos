package com.bup.sanalpos.rota

/**
 * Cihazdaki km sayacı (0.13.3, ROTA_MIMARI M23). Gönderilen noktalar 15 sn'de birdir; aradaki virajlar
 * ve dur-kalktaki konum titremesi km'yi bozar (21 Kasım: konumdan ve hızdan hesap %3–6 ayrıştı). Sayaç
 * hareketteyken saniyelik GPS'i görür ve toplam yolu metre olarak tutar; her noktaya o anki toplam
 * yazılır (sözleşmede `o`). İki nokta arası yol = toplamlar farkı.
 *
 * Yöntem, iki GPS ölçümü arasına göre:
 * - **≤ [SIK_SN] sn ve iki ölçümde de hız var:** uydunun ölçtüğü hız (Doppler; konum titremesinden
 *   etkilenmez) zamanla toplanır (yamuk kuralı). [DURAN_HIZ_MS] altındaki hız sıfır sayılır: duran araçta
 *   ölçülen birkaç cm/sn saatlerce toplanıp yol olmasın.
 * - **Diğer:** iki konum arası düz mesafe; ancak iki doğruluk payının toplamından kısaysa titreme sayılır,
 *   sayılmaz ve çapa yerinde kalır (yavaş gerçek hareket birikip eşiği aşınca sayılır).
 * - Doğruluğu [EN_KOTU_DOGRULUK_M]'den kötü, sahte ya da ağ kaynaklı ölçüm hiç kullanılmaz.
 * - Sıçrama yok sayılır, çapa korunur: hızın izin verdiğinden çok uzak konum ya da [EN_YUKSEK_HIZ_MS]'den
 *   hızlı görünen yer değiştirme. Tek ölçümde bozuk hız ise konumdan hesaplanır.
 *
 * Saf ve tek iş parçacıklıdır (RotaHizmeti'nin konum iş parçacığı). Durum [durum] ile saklanır, [yukle] ile
 * geri gelir: hizmet yeniden başlasa da toplam sürer, aradaki süre "boşluk" kuralıyla (düz çizgi) kapanır.
 */
class KmSayaci {
    /** Saklanan durum: toplam ve son kabul edilen ölçüm. */
    data class Durum(val toplamM: Double, val zaman: Long, val enlem: Double, val boylam: Double, val dogruluk: Double)

    private var toplam = 0.0
    private var capa: Nokta? = null

    /** Şimdiye kadarki toplam yol (m, aşağı yuvarlanmış). */
    val toplamM: Long get() = toplam.toLong()

    val durum: Durum? get() = capa?.let { Durum(toplam, it.zaman, it.enlem, it.boylam, it.dogruluk) }

    fun yukle(d: Durum?) {
        if (d == null || capa != null || !(d.toplamM >= 0.0) || d.toplamM.isInfinite()) return
        toplam = d.toplamM
        capa = Nokta(0, d.zaman, d.enlem, d.boylam, d.dogruluk, null, null, null, NoktaKaynagi.GPS, false)
    }

    /** Bir GPS ölçümünü işler. Döner: eklenen yol (m). */
    fun ekle(n: Nokta): Double {
        if (n.kaynak != NoktaKaynagi.GPS || n.sahte || !(n.dogruluk <= EN_KOTU_DOGRULUK_M)) return 0.0
        val c = capa ?: run {
            capa = n
            return 0.0
        }
        val dtSn = (n.zaman - c.zaman) / 1000.0
        if (dtSn <= 0.0) return 0.0
        val duz = Mesafe.metre(c.enlem, c.boylam, n.enlem, n.boylam)
        val v1 = c.hiz
        val v2 = n.hiz
        val yol = if (dtSn <= SIK_SN && v1 != null && v2 != null) {
            val ort = (sifirla(v1) + sifirla(v2)) / 2
            val hizdan = ort * dtSn
            // Konum sıçradı (hızın izin vermediği kadar uzak): ölçüm yok sayılır, çapa kaymaz.
            if (duz > 2 * hizdan + SICRAMA_PAYI_M) return 0.0
            // Bozuk hız ölçümü (nadir): düz mesafeden çok uzunsa düz mesafe.
            if (hizdan > 1.5 * duz + HIZ_PAYI_M) duz else hizdan
        } else {
            if (duz < c.dogruluk + n.dogruluk + TITREME_PAYI_M) return 0.0
            duz
        }
        if (yol / dtSn > EN_YUKSEK_HIZ_MS) return 0.0
        toplam += yol
        capa = n
        return yol
    }

    private fun sifirla(v: Double) = if (v < DURAN_HIZ_MS) 0.0 else v

    companion object {
        /** Bundan sık ölçümlerde hız toplanır (saniyelik GPS; arada kaçan bir-iki ölçüm de olur). */
        const val SIK_SN = 5.0
        const val DURAN_HIZ_MS = 0.5
        const val EN_KOTU_DOGRULUK_M = 30.0
        const val TITREME_PAYI_M = 5.0
        const val SICRAMA_PAYI_M = 30.0
        const val HIZ_PAYI_M = 10.0

        /** 180 km/sa (CAL_bup sıçrama eşiğiyle aynı). */
        const val EN_YUKSEK_HIZ_MS = 50.0
    }
}
