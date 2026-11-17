package com.bup.sanalpos.rota

import android.Manifest
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.bup.sanalpos.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Gizli "Konum kurulumu" ekranının kanalı ("bup/rota", Dart: lib/data/android/rota_kurulumu.dart).
 * Yalnız kurulum için: izinler, pil muafiyeti, hizmeti başlatma, durum. Konum verisi, kimlik veya
 * merkez ayarı bu kanaldan değiştirilemez (rota yetkisi terminalde yok, M4).
 */
class RotaKanali(messenger: BinaryMessenger, private val etkinlik: MainActivity) : MethodChannel.MethodCallHandler {
    private val kanal = MethodChannel(messenger, "bup/rota")
    private val arka = Executors.newSingleThreadExecutor()
    private var bekleyenIzin: MethodChannel.Result? = null

    init {
        kanal.setMethodCallHandler(this)
    }

    override fun onMethodCall(cagri: MethodCall, sonuc: MethodChannel.Result) {
        when (cagri.method) {
            "durum" -> arka.execute {
                val d = runCatching { durum() }
                etkinlik.runOnUiThread { d.fold({ sonuc.success(it) }, { sonuc.error("hata", null, null) }) }
            }
            "konumIzni" -> izinIste(Manifest.permission.ACCESS_FINE_LOCATION, sonuc)
            "arkaPlanIzni" -> {
                if (!RotaHizmeti.izinVar(etkinlik)) {
                    sonuc.error("once_konum", null, null)
                } else {
                    // Android 11+: sistem bu istekte uygulamanın konum izni sayfasını açar
                    // ("Her zaman izin ver" orada seçilir).
                    izinIste(Manifest.permission.ACCESS_BACKGROUND_LOCATION, sonuc)
                }
            }
            "pilMuafiyeti" -> {
                etkinlik.startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${etkinlik.packageName}")),
                )
                sonuc.success(null)
            }
            "konumAyari" -> {
                etkinlik.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                sonuc.success(null)
            }
            "baslat" -> sonuc.success(RotaHizmeti.baslat(etkinlik, "kurulum"))
            else -> sonuc.notImplemented()
        }
    }

    private fun izinIste(izin: String, sonuc: MethodChannel.Result) {
        if (bekleyenIzin != null) {
            sonuc.error("mesgul", null, null)
            return
        }
        bekleyenIzin = sonuc
        etkinlik.konumIzniIste(izin)
    }

    /** MainActivity'nin izin penceresi sonucu. İzin verildiyse hizmet hemen başlar. */
    fun izinSonucu(verildi: Boolean) {
        if (verildi) RotaHizmeti.baslat(etkinlik, "kurulum")
        bekleyenIzin?.success(verildi)
        bekleyenIzin = null
    }

    private fun durum(): Map<String, Any?> {
        val c = etkinlik.applicationContext
        val etkin = RotaBulut.etkin
        val uid = if (etkin) runCatching { RotaBulut.al(c).bilinenKimlik }.getOrNull() else null
        val ayar = AyarDeposu(c).ayar
        val izin = { p: String -> c.checkSelfPermission(p) == android.content.pm.PackageManager.PERMISSION_GRANTED }
        return mapOf(
            "etkin" to etkin,
            "kod" to uid?.let { TerminalKodu.uret(it) },
            "konumIzni" to izin(Manifest.permission.ACCESS_FINE_LOCATION),
            "arkaPlanIzni" to izin(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            "pilMuaf" to c.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(c.packageName),
            "konumAcik" to c.getSystemService(LocationManager::class.java).isLocationEnabled,
            "hizmet" to RotaHizmeti.calisiyor,
            "onayli" to ayar.aktif,
            "takip" to ayar.calisir,
            "bekleyen" to NoktaKuyrugu.al(c).sayi(),
            "android" to Build.VERSION.SDK_INT,
        )
    }
}
