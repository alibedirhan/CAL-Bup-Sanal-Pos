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
 */
class KonumAlici(
    private val lm: LocationManager,
    private val looper: Looper,
    private val noktaGeldi: (Nokta) -> Unit,
) {
    private var aralikMs = 0L
    private var sonGpsMs = Long.MIN_VALUE / 2
    private val gps = LocationListener { konumGeldi(it, NoktaKaynagi.GPS) }
    private val ag = LocationListener { konumGeldi(it, NoktaKaynagi.AG) }

    val calisiyor: Boolean get() = aralikMs > 0

    /** İzin denetimi çağırandadır (RotaHizmeti); izin yoksa SecurityException. */
    @SuppressLint("MissingPermission")
    fun baslat(aralikSn: Int) {
        val yeni = aralikSn * 1000L
        if (yeni == aralikMs) return
        durdur()
        aralikMs = yeni
        if (lm.allProviders.contains(LocationManager.GPS_PROVIDER)) {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, aralikMs, 0f, gps, looper)
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
    }

    private fun konumGeldi(l: Location, kaynak: NoktaKaynagi) {
        val simdi = android.os.SystemClock.elapsedRealtime()
        if (kaynak == NoktaKaynagi.GPS) {
            sonGpsMs = simdi
        } else if (simdi - sonGpsMs < 2 * aralikMs) {
            return
        }
        noktaGeldi(cevir(l, kaynak))
    }

    companion object {
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
