package com.bup.sanalpos.rota

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Bekçi (M19): rota hizmeti bir sebeple öldüyse ve kendiliğinden geri gelmediyse yeniden başlatır.
 *
 * Neden gerekli: 17 Kasım 2026 gecesi Ali'nin telefonunda Google Play Hizmetleri güncellendi; Android ona
 * bağlı süreçleri kapattı ("stop com.google.android.gms due to installPackageLI") ve hizmet bir daha
 * başlamadı (START_STICKY bu kapatmada işlemez). Açılış/güncelleme alıcısı yalnız o iki olayda çalışır.
 *
 * Sistemin iş zamanlayıcısıyla 15 dakikada bir (Android'in en kısa periyodu), telefon yeniden başlasa da
 * kalıcı. Hizmet çalışıyorsa hiçbir şey yapmaz. Android 12+'da arka plandan ön plan hizmeti başlatmak
 * yalnız pil iyileştirmesinden muaf uygulamaya açıktır; kurulum ekranı bu muafiyeti ister.
 * Kullanıcı "Durmaya zorla" derse Android bekçiyi de siler (açılış ya da uygulama açılışı kurar).
 *
 * İkinci bekçi [RotaBekciAlarmi]: muafiyet sonradan kalkarsa iş zamanlayıcısının başlatması reddedilir
 * (emülatörde ölçüldü: "Background started FGS: Disallowed"). Tam zamanlı alarm ise ön plan hizmeti
 * başlatma istisnasıdır; aynı aralıkla kendini yeniden kurar.
 */
class RotaBekci : JobService() {
    override fun onStartJob(p: JobParameters?): Boolean {
        if (!RotaHizmeti.calisiyor) RotaHizmeti.baslat(this, NEDEN)
        return false
    }

    override fun onStopJob(p: JobParameters?): Boolean = false

    /** Tam zamanlı alarmın alıcısı: hizmet yoksa başlatır, sonraki alarmı kurar. */
    class RotaBekciAlarmi : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            if (!RotaHizmeti.calisiyor) RotaHizmeti.baslat(c, NEDEN_ALARM)
            alarmKur(c)
        }
    }

    companion object {
        const val IS_NO = 4702
        const val NEDEN = "bekci"
        const val NEDEN_ALARM = "bekci_alarm"
        private const val PERIYOT_MS = 15 * 60_000L

        /**
         * Alarm bekçisini (yeniden) kurar. Duvar saatiyle (RTC): telefon uykudayken de uyandırır. Tam alarm
         * izni yoksa (Android 12+'da kullanıcı kapatabilir) yaklaşık alarm kurulur; o zaman istisna yoktur.
         */
        fun alarmKur(c: Context) {
            val am = c.getSystemService(AlarmManager::class.java) ?: return
            val pi = PendingIntent.getBroadcast(
                c,
                IS_NO,
                Intent(c, RotaBekciAlarmi::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val zaman = System.currentTimeMillis() + PERIYOT_MS
            runCatching {
                if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
                }
            }
        }

        /** İki bekçiyi kurar: alarm her seferinde yeniden; iş zaten kuruluysa dokunulmaz (periyodu sıfırlanmasın). */
        fun kur(c: Context) {
            alarmKur(c)
            val js = c.getSystemService(JobScheduler::class.java) ?: return
            if (js.getPendingJob(IS_NO) != null) return
            runCatching {
                js.schedule(
                    JobInfo.Builder(IS_NO, ComponentName(c, RotaBekci::class.java))
                        .setPeriodic(PERIYOT_MS)
                        .setPersisted(true)
                        .build(),
                )
            }
        }
    }
}
