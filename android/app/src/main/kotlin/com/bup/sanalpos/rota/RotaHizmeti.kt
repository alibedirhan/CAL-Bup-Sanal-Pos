package com.bup.sanalpos.rota

import android.Manifest
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import com.google.firebase.firestore.ListenerRegistration

/**
 * Konum ön plan hizmeti (M1, ROTA_MIMARI §5). İki iş parçacığı:
 * - **konum**: konum, sıklık politikası, olaylar, kuyruğa yazma (hiç ağ beklemez);
 * - **ağ**: Firebase oturumu, başvuru, merkez dinleme, gönderim (engelleyici çağrılar burada).
 * Paylaşılan tek şey kuyruk (SQLite, iş parçacığı güvenli) ve iki @Volatile anlık değerdir.
 *
 * Terminalde görünen hiçbir şey yoktur (K24): bildirim en düşük önemde ve Android 13+'ta bildirim
 * izni istenmediği için çubukta çıkmaz (M17).
 */
class RotaHizmeti : Service() {
    private val konumIs = HandlerThread("rota-konum")
    private val agIs = HandlerThread("rota-ag")
    private lateinit var konumH: Handler
    private lateinit var agH: Handler
    private lateinit var kuyruk: NoktaKuyrugu
    private lateinit var depo: AyarDeposu
    private lateinit var lm: LocationManager
    private lateinit var alici: KonumAlici

    /**
     * Gönderim için kısa uyanıklık (0.13.2). Ekran kapalı ve şarjsızken işlemci uyur; Handler'ın
     * gecikmeli işleri uyurken ilerlemeyen saate bağlıdır. 20 Kasım 2026 TC15'te gönderim 4–20 dk
     * gecikiyordu. Konum gelince (işlemciyi sistem uyandırır) kilit alınır, gönderim denetimi bitince
     * bırakılır; en çok [UYANIK_MS].
     */
    private lateinit var uyanik: PowerManager.WakeLock
    private var basladi = false

    // --- konum iş parçacığına ait ---
    private val politika = OrneklemePolitikasi()
    private val saat = SaatFarki()
    private val km = KmSayaci()
    private var sonKurulumDenetimi = Long.MIN_VALUE / 2
    private var ayar = TakipAyari.KAPALI
    private var depolar = emptyList<Depo>()
    private var konumAcik = true
    private var sonSahte = false

    // --- iki iş parçacığının okuduğu anlık değerler ---
    @Volatile private var sonNokta: Nokta? = null
    @Volatile private var durum = TerminalDurumu.ONAY_BEKLIYOR
    @Volatile private var onayli = false
    @Volatile private var gonderimSn = TakipAyari.VARSAYILAN_GONDERIM_SN

    // --- ağ iş parçacığına ait ---
    private var bulut: RotaBulut? = null
    private var gonderici: Gonderici? = null
    private var dinleme: ListenerRegistration? = null
    private val agGeri = GeriCekilme(ilkMs = 30_000)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        konumIs.start()
        agIs.start()
        konumH = Handler(konumIs.looper)
        agH = Handler(agIs.looper)
        kuyruk = NoktaKuyrugu.al(this)
        depo = AyarDeposu(this)
        // Saat referansı (M21) her yolda geçerli olsun: izin yokken erken biten başlatmada da olay yazılır.
        saat.yukle(depo.saatReferansi, acilisSayisi())
        lm = getSystemService(LocationManager::class.java)
        alici = KonumAlici(lm, konumIs.looper, hamGps = { kmGeldi(it) }) { noktaGeldi(it) }
        uyanik = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "bup:rota-gonderim")
            .apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val neden = intent?.getStringExtra(NEDEN) ?: "sistem"
        if (!RotaBulut.etkin || !onPlanaGec()) {
            // İzin yok (ya da geri alındı): olay kuyruğa yazılır, hizmet durur. İzin verilince
            // uygulama açılışı hizmeti yeniden başlatır.
            konumH.post { olay(OlayTuru.IZIN_YOK, neden) }
            stopSelf()
            return START_NOT_STICKY
        }
        calisiyor = true
        RotaBekci.kur(this)
        if (!basladi) {
            basladi = true
            konumH.post { basla(neden) }
        } else if (neden == NEDEN_ACILIS) {
            konumH.post { olay(OlayTuru.ACILIS) }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        calisiyor = false
        konumH.post { alici.durdur() }
        agH.post { dinleme?.remove() }
        runCatching { unregisterReceiver(olayAlicisi) }
        konumIs.quitSafely()
        agIs.quitSafely()
        if (uyanik.isHeld) uyanik.release()
        super.onDestroy()
    }

    private fun onPlanaGec(): Boolean = try {
        if (!izinVar(this)) throw SecurityException("Konum izni yok")
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(BILDIRIM_NO, CihazBilgisi.bildirim(this, KANAL), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(BILDIRIM_NO, CihazBilgisi.bildirim(this, KANAL))
        }
        true
    } catch (e: Exception) {
        false
    }

    // ===================== konum iş parçacığı =====================

    private fun basla(neden: String) {
        olay(OlayTuru.HIZMET_BASLADI, neden)
        if (neden == NEDEN_ACILIS) olay(OlayTuru.ACILIS)
        ayar = depo.ayar
        depolar = depo.depolar
        onayli = ayar.aktif
        gonderimSn = ayar.gonderimSn
        politika.ayarla(ayar, depolar)
        km.yukle(depo.kmDurumu)
        kurulumuDenetle(her = true)
        konumAcik = lm.isLocationEnabled
        val onceki = depo.konumAcikti
        if (onceki != null && onceki != konumAcik) olay(if (konumAcik) OlayTuru.KONUM_ACILDI else OlayTuru.KONUM_KAPANDI)
        depo.konumAcikti = konumAcik
        val filtre = IntentFilter().apply {
            addAction(LocationManager.PROVIDERS_CHANGED_ACTION)
            addAction(Intent.ACTION_BATTERY_LOW)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_SHUTDOWN)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(olayAlicisi, filtre, null, konumH, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(olayAlicisi, filtre, null, konumH)
        }
        takibiUygula()
        konumH.postDelayed(bakim, BAKIM_MS)
        agH.post(agBasla)
    }

    private val olayAlicisi = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                LocationManager.PROVIDERS_CHANGED_ACTION -> {
                    val acik = lm.isLocationEnabled
                    if (acik == konumAcik) return
                    konumAcik = acik
                    depo.konumAcikti = acik
                    olay(if (acik) OlayTuru.KONUM_ACILDI else OlayTuru.KONUM_KAPANDI)
                    takibiUygula()
                }
                Intent.ACTION_BATTERY_LOW -> olay(OlayTuru.PIL_DUSUK, "%${pil().first}")
                Intent.ACTION_TIME_CHANGED -> olay(OlayTuru.SAAT_DEGISTI, "fark ${saatFarki() / 1000} sn")
                Intent.ACTION_SHUTDOWN -> olay(OlayTuru.KAPANIS)
            }
        }
    }

    private fun olay(tur: OlayTuru, ayrinti: String? = null) {
        kuyruk.ekle(tur, gercekZaman(), ayrinti)
    }

    // --- saat (M21): olay ve ağ konumu zamanları cihaz saatiyle değil gerçek zaman tahminiyle ---
    private var sonSaklama = Long.MIN_VALUE / 2

    private fun gercekZaman(): Long =
        saat.simdi(System.currentTimeMillis(), SystemClock.elapsedRealtime(), agSaati())

    private fun saatFarki(): Long =
        saat.fark(System.currentTimeMillis(), SystemClock.elapsedRealtime(), agSaati())

    private fun agSaati(): Long? = CihazBilgisi.agSaati()

    private fun acilisSayisi(): Int = CihazBilgisi.acilisSayisi(this)

    private fun noktaGeldi(gelen: Nokta) {
        if (!ayar.calisir) return
        val tekduze = SystemClock.elapsedRealtime()
        val n = if (gelen.kaynak == NoktaKaynagi.GPS) {
            gelen
        } else {
            // Ağ konumunun zamanı cihaz saatidir: aynı yaşla gerçek zamana taşınır (M21).
            gelen.copy(zaman = saat.duzelt(gelen.zaman, System.currentTimeMillis(), tekduze, agSaati()))
        }
        if (n.kaynak == NoktaKaynagi.GPS && !n.sahte) {
            saat.gpsGeldi(n.zaman, tekduze, acilisSayisi())
            // Saklama seyrek (10 dk): tekdüze saatin kayması günde bir saniyenin altındadır.
            if (tekduze - sonSaklama >= 10 * 60_000L) {
                depo.saatReferansi = saat.referans
                sonSaklama = tekduze
            }
        }
        if (n.sahte && !sonSahte) olay(OlayTuru.SAHTE_KONUM)
        sonSahte = n.sahte
        val k = kuyruk.ekle(n.copy(km = km.toplamM))
        depo.kmDurumu = km.durum
        sonNokta = k
        val karar = politika.degerlendir(k)
        alici.baslat(karar.aralikSn, sikGps(), erken = karar.durum == TerminalDurumu.DURGUN)
        durum = durumHesapla()
        if (tekduze - sonKurulumDenetimi >= KURULUM_DENETIM_MS) kurulumuDenetle(her = false)
        // Uyurken zamanlayıcı ilerlemez: gönderim zamanı geldiyse şimdi (Gonderici tekdüze saatle sınırlar).
        uyanik.acquire(UYANIK_MS)
        gonderimiTetikle()
    }

    /** Her GPS ölçümü (saniyelik olabilir; M23): yalnız km sayacı. Kayıt [noktaGeldi]'de. */
    private fun kmGeldi(n: Nokta) {
        if (ayar.calisir) km.ekle(n)
    }

    private fun sikGps(): Boolean {
        val (p, sarj) = pil()
        return OrneklemePolitikasi.sikGps(politika.simdikiKarar.durum, p, sarj)
    }

    /**
     * Kurulum durumu (0.13.3): pil kısıtlaması ve arka plan konum izni merkeze olay olarak gider. Hizmet
     * başlarken her zaman ([her]), değişince hemen, değişmese de [KURULUM_YINELEME_MS]'de bir (merkez her gün
     * görsün); denetim en sık [KURULUM_DENETIM_MS]'de bir.
     */
    private fun kurulumuDenetle(her: Boolean) {
        sonKurulumDenetimi = SystemClock.elapsedRealtime()
        val ayrinti = CihazBilgisi.kurulum(this)
        val simdi = gercekZaman()
        if (her || ayrinti != depo.sonKurulum || simdi - depo.sonKurulumZamani >= KURULUM_YINELEME_MS) {
            olay(OlayTuru.KURULUM, ayrinti)
            depo.sonKurulum = ayrinti
            depo.sonKurulumZamani = simdi
        }
    }

    private fun ayarGeldi(a: TakipAyari?) {
        val yeni = a ?: TakipAyari.KAPALI
        if (yeni.calisir != ayar.calisir) olay(if (yeni.calisir) OlayTuru.TAKIP_ACILDI else OlayTuru.TAKIP_KAPANDI)
        ayar = yeni
        depo.ayar = yeni
        onayli = yeni.aktif
        gonderimSn = yeni.gonderimSn
        politika.ayarla(yeni, depolar)
        takibiUygula()
        if (yeni.aktif) {
            agH.post(depolariYukle)
            gonderimiTetikle()
        }
    }

    private fun takibiUygula() {
        if (ayar.calisir && konumAcik && izinVar(this)) {
            val karar = politika.simdikiKarar
            runCatching { alici.baslat(karar.aralikSn, sikGps(), erken = karar.durum == TerminalDurumu.DURGUN) }.onFailure { olay(OlayTuru.IZIN_YOK, it.javaClass.simpleName) }
        } else {
            alici.durdur()
        }
        durum = durumHesapla()
    }

    private fun durumHesapla(): TerminalDurumu = when {
        !izinVar(this) -> TerminalDurumu.IZIN_YOK
        !konumAcik -> TerminalDurumu.KONUM_KAPALI
        !ayar.aktif -> TerminalDurumu.ONAY_BEKLIYOR
        !ayar.takip -> TerminalDurumu.KAPALI
        else -> politika.simdikiKarar.durum
    }

    private val bakim: Runnable = object : Runnable {
        override fun run() {
            kuyruk.bakim(gercekZaman())
            kurulumuDenetle(her = false)
            konumH.postDelayed(this, BAKIM_MS)
        }
    }

    // ===================== ağ iş parçacığı =====================

    private val agBasla: Runnable = object : Runnable {
        override fun run() = try {
            val b = RotaBulut.al(this@RotaHizmeti)
            val uid = b.kimlik()
            if (depo.basvuruKimligi != uid) {
                b.basvur(BasvuruBelgesi.olustur(uid, Build.MODEL, Build.MANUFACTURER, Build.VERSION.SDK_INT, surum()))
                depo.basvuruKimligi = uid
            }
            bulut = b
            // Duruma göre aralık (M24): depoda ve dururken seyrek, harekette merkezin aralığı.
            gonderici = Gonderici(uid, kuyruk, b, gonderimMs = { TakipAyari.gonderimMs(gonderimSn, durum) })
            dinlemeKur()
            agGeri.basarili()
            gonderimiTetikle()
        } catch (e: Exception) {
            // Ağ yok / oturum açılamadı: konum toplama sürer (kuyruk), ağ işi sonra yeniden denenir.
            agGeri.basarisiz(SystemClock.elapsedRealtime())
            agH.postDelayed(this, agGeri.beklenecekMs(SystemClock.elapsedRealtime()))
            Unit
        }
    }

    private fun dinlemeKur() {
        val b = bulut ?: return
        dinleme?.remove()
        dinleme = b.cihazDinle({ konumH.post(it) }, { a -> ayarGeldi(a) }) {
            // Yetki/oturum hatası: dinleme bitti. 5 dk sonra yeniden kurulur.
            agH.postDelayed({ dinlemeKur() }, 5 * 60_000L)
        }
    }

    private val depolariYukle = Runnable {
        val b = bulut ?: return@Runnable
        val yeni = runCatching { b.depolar() }.getOrNull() ?: return@Runnable
        konumH.post {
            depolar = yeni
            depo.depolar = yeni
            politika.ayarla(ayar, yeni)
        }
    }

    private val gonderim: Runnable = object : Runnable {
        override fun run() = try {
            gonder()
        } finally {
            if (uyanik.isHeld) uyanik.release()
        }

        private fun gonder() {
            val g = gonderici ?: return
            if (!onayli) return
            val (pil, sarj) = pil()
            val r = g.calis(
                SystemClock.elapsedRealtime(),
                Anlik(System.currentTimeMillis(), pil, sarj, surum()),
                durum.kod,
            ) { bekleyen -> DurumBelgesi.olustur(sonNokta, durum, pil, sarj, bekleyen, surum()) }
            agH.postDelayed(this, r.sonrakiMs)
        }
    }

    private fun gonderimiTetikle() {
        agH.removeCallbacks(gonderim)
        agH.post(gonderim)
    }

    // ===================== ortak =====================

    private fun pil(): Pair<Int, Boolean> = CihazBilgisi.pil(this)

    private fun surum(): Long = CihazBilgisi.surum(this)

    companion object {
        private const val KANAL = "rota"
        private const val BILDIRIM_NO = 4701
        private const val BAKIM_MS = 60 * 60_000L
        private const val UYANIK_MS = 30_000L
        private const val KURULUM_DENETIM_MS = 10 * 60_000L
        private const val KURULUM_YINELEME_MS = 6 * 3_600_000L
        const val NEDEN = "neden"
        const val NEDEN_ACILIS = "acilis"

        /** Kurulum ekranı için (aynı süreç). */
        @Volatile var calisiyor = false
            private set

        fun izinVar(c: Context): Boolean =
            c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

        /** Rota kapalıysa ya da izin yoksa başlatmaz. Döner: başlatıldı mı. */
        fun baslat(c: Context, neden: String): Boolean {
            if (!RotaBulut.etkin || !izinVar(c)) return false
            return runCatching {
                c.startForegroundService(Intent(c, RotaHizmeti::class.java).putExtra(NEDEN, neden))
            }.isSuccess
        }
    }
}
