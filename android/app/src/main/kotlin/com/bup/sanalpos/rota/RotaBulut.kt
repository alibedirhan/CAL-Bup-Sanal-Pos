package com.bup.sanalpos.rota

import android.content.Context
import com.bup.sanalpos.BuildConfig
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.FirebaseFirestoreSettings
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.MemoryCacheSettings
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Rota'nın Firebase bağdaştırıcısı (M2, M5, M13). Sanal POS'un Flutter tarafındaki varsayılan
 * Firebase uygulamasından tamamen ayrı, "rota" adlı ikinci bir uygulama kullanır: kendi anonim
 * oturumu vardır, Ali'nin parolalı oturumunu ne görür ne kullanır. Firestore önbelleği yalnız
 * bellektedir; tek kalıcı kuyruk NoktaKuyrugu'dur.
 *
 * Bütün çağrılar engelleyicidir (Tasks.await) ve yalnız RotaHizmeti'nin iş parçacığından yapılır.
 */
class RotaBulut private constructor(private val app: FirebaseApp) : RotaSunucusu {
    private val auth = FirebaseAuth.getInstance(app)
    private val db = FirebaseFirestore.getInstance(app)

    /** Anonim kimlik: varsa aynısı, yoksa yeni (ilk açılış). Ağ yoksa hata. */
    fun kimlik(): String = auth.currentUser?.uid ?: bekle(auth.signInAnonymously()).user!!.uid

    /** Varsa son bilinen kimlik (ağ gerekmez). */
    val bilinenKimlik: String? get() = auth.currentUser?.uid

    private fun uid() = auth.currentUser?.uid ?: throw IllegalStateException("Rota oturumu yok")

    /** Başvuru yoksa bırakır (M3). Varsa dokunmaz. */
    fun basvur(belge: Map<String, Any?>) {
        val ref = db.collection("rotaBasvurular").document(uid())
        if (!bekle(ref.get()).exists()) bekle(ref.set(belgeye(belge)))
    }

    /** rotaCihazlar/{uid} dinlenir. Belge yoksa (onay yok) null verilir; okuma hatasında hiç çağrılmaz. */
    fun cihazDinle(dinleyici: (TakipAyari?) -> Unit, hata: (Exception) -> Unit): ListenerRegistration =
        db.collection("rotaCihazlar").document(uid()).addSnapshotListener { s, e ->
            if (e != null) hata(e) else if (s != null) dinleyici(ayar(s))
        }

    /** rotaAyar/genel (depolar). Yalnız onaylı terminal okuyabilir. */
    fun depolar(): List<Depo> = Depo.listeden(bekle(db.collection("rotaAyar").document("genel").get()).get("depolar"))

    override fun gonder(kimlik: String, parca: Map<String, Any?>, durum: Map<String, Any?>): GonderimYaniti {
        val parcaRef = db.collection("rotaParcalar").document(kimlik)
        val durumRef = db.collection("rotaSonDurum").document(uid())
        return when (val sonuc = yaz { db.batch().set(parcaRef, belgeye(parca)).set(durumRef, belgeye(durum)).commit() }) {
            GonderimSonucu.REDDEDILDI -> {
                // Parça önceki denemede ulaşmış olabilir (M6). Kural terminalin kendi parçasına bakmasına
                // izin verir. Okunamazsa (ağ) reddedilmiş sayılır ve sonra yeniden denenir.
                val var_ = runCatching { bekle(parcaRef.get()) }.getOrNull()
                val son = (var_?.get("son") as? Number)?.toLong()
                if (var_ != null && var_.exists() && son != null) GonderimYaniti(GonderimSonucu.ZATEN_VAR, son)
                else GonderimYaniti(sonuc)
            }
            else -> GonderimYaniti(sonuc)
        }
    }

    override fun durumYaz(durum: Map<String, Any?>): GonderimSonucu =
        yaz { db.collection("rotaSonDurum").document(uid()).set(belgeye(durum)) }

    private inline fun yaz(islem: () -> Task<*>): GonderimSonucu = try {
        bekle(islem())
        GonderimSonucu.TAMAM
    } catch (e: Exception) {
        val kod = (e.cause as? FirebaseFirestoreException ?: e as? FirebaseFirestoreException)?.code
        if (kod == FirebaseFirestoreException.Code.PERMISSION_DENIED) GonderimSonucu.REDDEDILDI else GonderimSonucu.GECICI
    }

    companion object {
        private const val AD = "rota"
        private const val BEKLEME_SN = 30L

        /** Yapılandırma yoksa veya deneme kipindeyse rota kapalıdır. */
        val etkin: Boolean get() = !BuildConfig.ROTA_DENEME && BuildConfig.ROTA_PROJE.isNotEmpty() &&
            BuildConfig.ROTA_API_KEY.isNotEmpty() && BuildConfig.ROTA_APP_ID.isNotEmpty() &&
            (!BuildConfig.ROTA_EMULATOR || BuildConfig.ROTA_PROJE.startsWith("demo-"))

        @Volatile private var ornek: RotaBulut? = null

        fun al(context: Context): RotaBulut {
            check(etkin) { "Rota yapılandırılmamış" }
            return ornek ?: synchronized(this) { ornek ?: RotaBulut(uygulama(context)).also { ornek = it } }
        }

        private fun uygulama(context: Context): FirebaseApp {
            FirebaseApp.getApps(context).firstOrNull { it.name == AD }?.let { return it }
            val app = FirebaseApp.initializeApp(
                context.applicationContext,
                FirebaseOptions.Builder()
                    .setApiKey(BuildConfig.ROTA_API_KEY)
                    .setApplicationId(BuildConfig.ROTA_APP_ID)
                    .setProjectId(BuildConfig.ROTA_PROJE)
                    .setGcmSenderId(BuildConfig.ROTA_GONDEREN)
                    .build(),
                AD,
            )
            val db = FirebaseFirestore.getInstance(app)
            if (BuildConfig.ROTA_EMULATOR) {
                FirebaseAuth.getInstance(app).useEmulator(BuildConfig.ROTA_EMULATOR_ADRESI, 9098)
                db.useEmulator(BuildConfig.ROTA_EMULATOR_ADRESI, 8088)
            }
            db.firestoreSettings = FirebaseFirestoreSettings.Builder()
                .setLocalCacheSettings(MemoryCacheSettings.newBuilder().build())
                .build()
            return app
        }

        private fun <T> bekle(t: Task<T>): T = try {
            Tasks.await(t, BEKLEME_SN, TimeUnit.SECONDS)
        } catch (e: TimeoutException) {
            throw IllegalStateException("Zaman aşımı", e)
        }

        private fun ayar(s: DocumentSnapshot): TakipAyari? = if (!s.exists()) null else TakipAyari.guvenli(
            s.get("aktif"), s.get("takip"), s.get("hareketSn"), s.get("durgunSn"), s.get("depoSn"),
        )

        internal fun belgeye(m: Map<String, Any?>): Map<String, Any?> = m.mapValues { donustur(it.value) }

        /** Saf belge değerlerini Firestore türlerine çevirir (Belgeler.kt sözleşmesi). */
        internal fun donustur(x: Any?): Any? = when (x) {
            is Zaman -> Timestamp(x.ms / 1000, ((x.ms % 1000) * 1_000_000).toInt())
            SunucuZamani -> FieldValue.serverTimestamp()
            is Double -> if (x.isNaN() || x.isInfinite()) null else x
            is Map<*, *> -> x.entries.associate { it.key.toString() to donustur(it.value) }
            is List<*> -> x.map { donustur(it) }
            else -> x
        }
    }
}
