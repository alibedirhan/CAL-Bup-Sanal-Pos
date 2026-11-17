package com.bup.sanalpos.rota

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Kalıcı nokta/olay kuyruğu (M5, ROTA_MIMARI §5). Sunucuda kayıt görülene kadar her kayıt burada
 * durur; uygulama öldürülse, telefon kapansa da kaybolmaz.
 *
 * Sıra numarası SQLite `AUTOINCREMENT` ile verilir: hiç geri gitmez, silinen numara yeniden
 * kullanılmaz. Nokta ve olay aynı tabloda olduğu için sıra ortak ve boşluksuzdur (sunucu
 * kuralı parça içinde boşluk kabul etmez). Sınır aşılırsa en eski kayıtlar silinir ve bunu
 * anlatan `kuyruk_tasti` olayı eklenir: sessiz kayıp yok.
 */
class NoktaKuyrugu(
    context: Context,
    dosya: String = DOSYA,
    private val enCokKayit: Long = 200_000,
    private val enEskiMs: Long = 35L * 24 * 3600 * 1000,
) : SQLiteOpenHelper(context.applicationContext, dosya, null, 1), KuyrukDeposu {

    override fun onConfigure(db: SQLiteDatabase) {
        // Yazma önceden günlüğe (WAL): çökmede yarım kayıt kalmaz, okuma yazmayı beklemez.
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE kayit (
                sira INTEGER PRIMARY KEY AUTOINCREMENT,
                tur INTEGER NOT NULL,
                zaman INTEGER NOT NULL,
                en REAL, boy REAL, dog REAL, hiz REAL, yon REAL, yuk REAL,
                kay TEXT, sahte INTEGER,
                olay TEXT, ayrinti TEXT)""",
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, eski: Int, yeni: Int) {
        // Şema 1. Değişirse burada veri koruyarak geçiş yazılır; kuyruk asla silinmez.
    }

    /** Noktayı ekler; [n].sira yok sayılır (0 olmalı), verilen sıra döner. */
    fun ekle(n: Nokta): Nokta {
        require(n.sira == 0L) { "Sıra kuyrukta verilir" }
        val v = ContentValues().apply {
            put("tur", TUR_NOKTA)
            put("zaman", n.zaman)
            put("en", n.enlem)
            put("boy", n.boylam)
            put("dog", n.dogruluk)
            put("hiz", n.hiz)
            put("yon", n.yon)
            put("yuk", n.rakim)
            put("kay", n.kaynak.kod)
            put("sahte", if (n.sahte) 1 else 0)
        }
        return n.copy(sira = writableDatabase.insertOrThrow("kayit", null, v))
    }

    fun ekle(tur: OlayTuru, zaman: Long, ayrinti: String? = null): Olay {
        val v = ContentValues().apply {
            put("tur", TUR_OLAY)
            put("zaman", zaman)
            put("olay", tur.kod)
            put("ayrinti", ayrinti?.take(Olay.AYRINTI_EN_COK))
        }
        val sira = writableDatabase.insertOrThrow("kayit", null, v)
        return Olay(sira, zaman, tur, ayrinti?.take(Olay.AYRINTI_EN_COK))
    }

    /** Kuyruğun başı (en eski), sıraya göre. */
    override fun bas(adet: Int): List<KuyrukKaydi> {
        val sonuc = ArrayList<KuyrukKaydi>(adet)
        readableDatabase.rawQuery("SELECT * FROM kayit ORDER BY sira LIMIT ?", arrayOf(adet.toString())).use { c ->
            val iSira = c.getColumnIndexOrThrow("sira")
            val iTur = c.getColumnIndexOrThrow("tur")
            val iZaman = c.getColumnIndexOrThrow("zaman")
            fun dbl(ad: String): Double? = c.getColumnIndexOrThrow(ad).let { if (c.isNull(it)) null else c.getDouble(it) }
            fun str(ad: String): String? = c.getColumnIndexOrThrow(ad).let { if (c.isNull(it)) null else c.getString(it) }
            while (c.moveToNext()) {
                val sira = c.getLong(iSira)
                val zaman = c.getLong(iZaman)
                if (c.getInt(iTur) == TUR_NOKTA) {
                    sonuc += KuyrukKaydi.N(
                        Nokta(
                            sira, zaman, dbl("en")!!, dbl("boy")!!, dbl("dog")!!, dbl("hiz"), dbl("yon"), dbl("yuk"),
                            if (str("kay") == NoktaKaynagi.AG.kod) NoktaKaynagi.AG else NoktaKaynagi.GPS,
                            sahte = c.getInt(c.getColumnIndexOrThrow("sahte")) == 1,
                        ),
                    )
                } else {
                    val tur = OlayTuru.entries.firstOrNull { it.kod == str("olay") } ?: continue
                    sonuc += KuyrukKaydi.O(Olay(sira, zaman, tur, str("ayrinti")))
                }
            }
        }
        return sonuc
    }

    /** Sunucuda görülen parçayı siler. */
    override fun sil(ilk: Long, son: Long): Int =
        writableDatabase.delete("kayit", "sira BETWEEN ? AND ?", arrayOf(ilk.toString(), son.toString()))

    override fun sayi(): Long = readableDatabase.compileStatement("SELECT COUNT(*) FROM kayit").use { it.simpleQueryForLong() }

    /**
     * Sınırları uygular: [enEskiMs]'den eski ve [enCokKayit]'ı aşan en eski kayıtlar silinir,
     * yerine silineni anlatan tek olay eklenir. Silinen yoksa null.
     */
    fun bakim(simdiMs: Long): Olay? {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val esik = simdiMs - enEskiMs
            var silinecekSon = db.compileStatement("SELECT IFNULL(MAX(sira), 0) FROM kayit WHERE zaman < ?").use {
                it.bindLong(1, esik)
                it.simpleQueryForLong()
            }
            val toplam = db.compileStatement("SELECT COUNT(*) FROM kayit").use { it.simpleQueryForLong() }
            // Eklenecek olaya da yer açılır: bakımdan sonra toplam en çok [enCokKayit] olur.
            val fazla = toplam - enCokKayit
            if (fazla > 0) {
                val tasmaSon = if (fazla + 1 >= toplam) {
                    Long.MAX_VALUE
                } else {
                    db.compileStatement("SELECT sira FROM kayit ORDER BY sira LIMIT 1 OFFSET ?").use {
                        it.bindLong(1, fazla + 1)
                        it.simpleQueryForLong()
                    } - 1
                }
                silinecekSon = maxOf(silinecekSon, tasmaSon)
            }
            if (silinecekSon <= 0) return null
            val ilk = db.compileStatement("SELECT MIN(sira) FROM kayit").use { it.simpleQueryForLong() }
            val adet = db.delete("kayit", "sira <= ?", arrayOf(silinecekSon.toString()))
            if (adet == 0) return null
            val olay = ekle(OlayTuru.KUYRUK_TASTI, simdiMs, "$adet kayıt silindi, sıra $ilk–$silinecekSon")
            db.setTransactionSuccessful()
            return olay
        } finally {
            db.endTransaction()
        }
    }

    companion object {
        const val DOSYA = "rota_kuyruk.db"
        private const val TUR_NOKTA = 0
        private const val TUR_OLAY = 1

        @Volatile private var ornek: NoktaKuyrugu? = null

        /** Uygulama boyunca tek bağlantı (SQLite yardımcısı iş parçacıkları arasında güvenlidir). */
        fun al(context: Context): NoktaKuyrugu =
            ornek ?: synchronized(this) { ornek ?: NoktaKuyrugu(context).also { ornek = it } }
    }
}
