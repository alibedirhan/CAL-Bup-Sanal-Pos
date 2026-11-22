package com.bup.sanalpos.rota

import kotlin.math.max

/**
 * Akıllı sıklık (M9, ROUTE_PLANI §4.1, §4.2b). Her yeni noktaya bakıp terminalin durumunu ve
 * bir sonraki noktanın kaç saniye sonra isteneceğini söyler. Saf ve tek iş parçacıklıdır:
 * çağıran (RotaHizmeti) noktaları sırayla verir.
 *
 * - **Depoda:** nokta depo yarıçapı içindeyse ve art arda [DEPO_ONAY_NOKTA] nokta öyleyse.
 *   Çıkış için yarıçap + [DEPO_CIKIS_PAYI_M] dışına çıkmak gerekir (sınırda gidip gelmesin).
 * - **Hareket:** hız ≥ [HAREKET_HIZI_MS] ya da son "çapa" noktasından yeterince uzaklaşma.
 * - **Durgun:** [DURGUN_SURE_MS] boyunca hareket yok.
 * - Zayıf (doğruluğu çok kötü) nokta durumu değiştirmez (M10).
 */
class OrneklemePolitikasi(
    private var ayar: TakipAyari = TakipAyari.KAPALI,
    private var depolar: List<Depo> = emptyList(),
) {
    data class Karar(val durum: TerminalDurumu, val aralikSn: Int)

    private var durum = TerminalDurumu.HAREKET
    private var capa: Nokta? = null
    private var sonHareketMs = Long.MIN_VALUE
    private var depoIcindeArdisik = 0

    fun ayarla(yeniAyar: TakipAyari, yeniDepolar: List<Depo>) {
        ayar = yeniAyar
        depolar = yeniDepolar
    }

    val simdikiKarar: Karar get() = Karar(durum, aralik(durum))

    fun degerlendir(n: Nokta): Karar {
        if (n.zayif) return simdikiKarar
        if (durum == TerminalDurumu.DEPODA) {
            if (!depodanCikti(n)) return simdikiKarar
            depoIcindeArdisik = 0
            hareketBasladi(n)
            return simdikiKarar
        }
        if (depolar.any { Mesafe.metre(n.enlem, n.boylam, it.enlem, it.boylam) <= it.yaricap }) {
            depoIcindeArdisik++
            if (depoIcindeArdisik >= DEPO_ONAY_NOKTA) {
                durum = TerminalDurumu.DEPODA
                capa = n
                return simdikiKarar
            }
        } else {
            depoIcindeArdisik = 0
        }
        val c = capa
        val esik = max(HAREKET_MESAFESI_M, 2 * n.dogruluk)
        val hizli = (n.hiz ?: 0.0) >= HAREKET_HIZI_MS
        if (c == null || hizli || Mesafe.metre(c.enlem, c.boylam, n.enlem, n.boylam) > esik) {
            hareketBasladi(n)
        } else if (n.zaman - sonHareketMs >= DURGUN_SURE_MS) {
            durum = TerminalDurumu.DURGUN
        }
        return simdikiKarar
    }

    private fun depodanCikti(n: Nokta) = depolar.none {
        Mesafe.metre(n.enlem, n.boylam, it.enlem, it.boylam) <= it.yaricap + DEPO_CIKIS_PAYI_M
    }

    private fun hareketBasladi(n: Nokta) {
        durum = TerminalDurumu.HAREKET
        capa = n
        sonHareketMs = n.zaman
    }

    private fun aralik(d: TerminalDurumu) = when (d) {
        TerminalDurumu.DURGUN -> ayar.durgunSn
        TerminalDurumu.DEPODA -> ayar.depoSn
        else -> ayar.hareketSn
    }

    companion object {
        /**
         * Km sayacı için saniyelik GPS (M23): hareketteyken her zaman; dururken (müşteride, trafikte) yalnız
         * pil yetiyorsa — kalkış anı kaçmasın, durak çıkışı km'ye düz çizgiyle girmesin. Depoda ve takip
         * dışında hayır (kayıt aralığı yeter).
         */
        fun sikGps(durum: TerminalDurumu, pil: Int, sarj: Boolean): Boolean = when (durum) {
            TerminalDurumu.HAREKET -> true
            TerminalDurumu.DURGUN -> sarj || pil >= SIK_GPS_EN_AZ_PIL
            else -> false
        }

        /**
         * Saniyelik GPS'te hangi ölçüm kayda gider (KonumAlici, M23): son iletimden [gecenMs] geçti. Kayıt
         * aralığı dolduysa (saniyelik ölçümler tam denk gelmez: [PAY_MS] pay) ya da araç dururken ([erken])
         * hızlandıysa (en erken [ERKEN_EN_AZ_MS] sonra) iletilir: politika hemen "hareket"e geçer.
         */
        fun iletilsinMi(gecenMs: Long, aralikMs: Long, hiz: Double?, erken: Boolean): Boolean =
            gecenMs >= aralikMs - PAY_MS ||
                (erken && hiz != null && hiz >= HAREKET_HIZI_MS && gecenMs >= ERKEN_EN_AZ_MS)

        const val PAY_MS = 500L
        const val ERKEN_EN_AZ_MS = 5_000L

        /** Şarjsızken bundan düşük pilde dururken saniyelik GPS kapanır. */
        const val SIK_GPS_EN_AZ_PIL = 30

        const val HAREKET_HIZI_MS = 2.0 // ~7 km/sa
        const val HAREKET_MESAFESI_M = 75.0
        const val DURGUN_SURE_MS = 3 * 60_000L
        const val DEPO_ONAY_NOKTA = 2
        const val DEPO_CIKIS_PAYI_M = 50.0
    }
}
