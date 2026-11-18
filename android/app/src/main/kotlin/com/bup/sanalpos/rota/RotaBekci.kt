package com.bup.sanalpos.rota

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context

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
 */
class RotaBekci : JobService() {
    override fun onStartJob(p: JobParameters?): Boolean {
        if (!RotaHizmeti.calisiyor) RotaHizmeti.baslat(this, NEDEN)
        return false
    }

    override fun onStopJob(p: JobParameters?): Boolean = false

    companion object {
        const val IS_NO = 4702
        const val NEDEN = "bekci"
        private const val PERIYOT_MS = 15 * 60_000L

        /** Bekçiyi kurar; zaten kuruluysa dokunmaz (periyot her başlatmada baştan sayılmasın). */
        fun kur(c: Context) {
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
