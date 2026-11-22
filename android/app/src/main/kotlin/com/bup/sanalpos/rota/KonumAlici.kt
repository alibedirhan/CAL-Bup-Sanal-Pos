package com.bup.sanalpos.rota

import android.annotation.SuppressLint
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Looper

/**
 * Android LocationManager üzerinden konum (M8): GPS asıl kaynak, ağ konumu yalnız GPS bir süredir
 * susmuşsa (tünel, kapalı alan) kullanılır. Google Play Hizmetleri gerekmez. Dinleyici verilen
 * döngüde (RotaHizmeti'nin iş parçacığı) çağrılır.
 *
 * **Saniyelik GPS (0.13.3, M23):** [sik] açıkken GPS saniyede bir istenir; her ölçüm [hamGps]'e (km sayacı)
 * gider, kayda ([noktaGeldi]) ise yine kayıt aralığında bir tanesi. Yavaş kayıt aralığındayken (dururken)
 * araç hızlanırsa ölçüm beklemeden kayda iletilir: kalkış anı ve durak bitişi kaçmaz.
 */
class KonumAlici(
    private val lm: LocationManager,
    private val looper: Looper,
    private val hamGps: (Nokta) -> Unit = {},
    private val noktaGeldi: (Nokta) -> Unit,
) {
    private var aralikMs = 0L
    private var sikMi = false
    private var erkenIlet = false
    private var sonGpsMs = Long.MIN_VALUE / 2
    private var sonIletilenMs = Long.MIN_VALUE / 2
    private val gps = LocationListener { konumGeldi(it, NoktaKaynagi.GPS) }
    private val ag = LocationListener { konumGeldi(it, NoktaKaynagi.AG) }

    val calisiyor: Boolean get() = aralikMs > 0

    /** İzin denetimi çağırandadır (RotaHizmeti); izin yoksa SecurityException. */
    @SuppressLint("MissingPermission")
    fun baslat(aralikSn: Int, sik: Boolean = false, erken: Boolean = false) {
        val yeni = aralikSn * 1000L
        erkenIlet = erken
        if (yeni == aralikMs && sik == sikMi) return
        durdur()
        aralikMs = yeni
        sikMi = sik
        if (lm.allProviders.contains(LocationManager.GPS_PROVIDER)) {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, if (sik) SIK_MS else aralikMs, 0f, gps, looper)
        }
        if (lm.allProviders.contains(LocationManager.NETWORK_PROVIDER)) {
            lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, aralikMs, 0f, ag, looper)
        }
    }

    fun durdur() {
        if (aralikMs == 0L) return
        lm.removeUpdates(gps)
        lm.removeUpdates(ag)
        aralikMs = 0
        sikMi = false
    }

    private fun konumGeldi(l: Location, kaynak: NoktaKaynagi) {
        val simdi = android.os.SystemClock.elapsedRealtime()
        val n = cevir(l, kaynak)
        if (kaynak == NoktaKaynagi.GPS) {
            sonGpsMs = simdi
            hamGps(n)
            if (!OrneklemePolitikasi.iletilsinMi(simdi - sonIletilenMs, aralikMs, n.hiz, erkenIlet)) return
        } else if (simdi - sonGpsMs < 2 * aralikMs) {
            return
        }
        sonIletilenMs = simdi
        noktaGeldi(n)
    }

    companion object {
        /** Saniyelik GPS isteği. */
        const val SIK_MS = 1_000L

        fun cevir(l: Location, kaynak: NoktaKaynagi): Nokta = Nokta(
            sira = 0,
            zaman = l.time,
            enlem = l.latitude,
            boylam = l.longitude,
            dogruluk = if (l.hasAccuracy()) l.accuracy.toDouble() else 9_999.0,
            hiz = if (l.hasSpeed()) l.speed.toDouble() else null,
            yon = if (l.hasBearing()) l.bearing.toDouble() else null,
            rakim = if (l.hasAltitude()) l.altitude else null,
            kaynak = kaynak,
            sahte = if (Build.VERSION.SDK_INT >= 31) l.isMock else @Suppress("DEPRECATION") l.isFromMockProvider,
        )
    }
}
