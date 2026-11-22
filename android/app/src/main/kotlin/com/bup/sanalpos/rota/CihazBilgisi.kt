package com.bup.sanalpos.rota

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import com.bup.sanalpos.R

/** Rota hizmetinin cihazdan okuduğu bilgiler (pil, sürüm, saat, kurulum). Yalnız okur, hiçbir ayarı değiştirmez. */
internal object CihazBilgisi {
    /** Pil yüzdesi ve şarjda mı. */
    fun pil(c: Context): Pair<Int, Boolean> {
        val i = c.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return 0 to false
        val seviye = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val olcek = i.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1)
        val sarj = i.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
        return (if (seviye < 0) 0 else seviye * 100 / olcek) to sarj
    }

    /** Uygulama sürümü (versionCode). */
    fun surum(c: Context): Long = runCatching {
        val p = c.packageManager.getPackageInfo(c.packageName, 0)
        if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong()
    }.getOrDefault(1L).coerceAtLeast(1L)

    /** Ağ saati (operatör/NTP; Android 13+); bilinmiyorsa null. */
    fun agSaati(): Long? = if (Build.VERSION.SDK_INT >= 33) {
        runCatching { SystemClock.currentNetworkTimeClock().millis() }.getOrNull()
    } else {
        null
    }

    fun acilisSayisi(c: Context): Int =
        runCatching { Settings.Global.getInt(c.contentResolver, Settings.Global.BOOT_COUNT) }.getOrDefault(-1)

    /** Kurulum olayının ayrıntısı: pil kısıtlaması kaldırılmış mı, arka plan konum izni ("her zaman") var mı. */
    fun kurulum(c: Context): String {
        val pilMuaf = c.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(c.packageName)
        val arka = Build.VERSION.SDK_INT < 29 ||
            c.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        return KurulumDurumu.ayrinti(pilMuaf, arka)
    }

    /** Ön plan hizmetinin zorunlu bildirimi: en düşük önem, sessiz, kilit ekranında gizli (K24, M17). */
    fun bildirim(c: Context, kanal: String): Notification {
        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(kanal, "Arka plan", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            },
        )
        return Notification.Builder(c, kanal)
            .setSmallIcon(R.drawable.ic_arka_plan)
            .setContentTitle("BUP Sanal POS")
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_SECRET)
            .build()
    }
}
