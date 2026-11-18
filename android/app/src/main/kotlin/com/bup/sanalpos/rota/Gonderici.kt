package com.bup.sanalpos.rota

/** Kuyruğun gönderici için gereken yüzü (NoktaKuyrugu; testte bellek içi taklit). */
interface KuyrukDeposu {
    fun bas(adet: Int): List<KuyrukKaydi>
    fun sil(ilk: Long, son: Long): Int
    fun sayi(): Long
}

enum class GonderimSonucu {
    /** Sunucu kabul etti. */
    TAMAM,

    /** Yazım reddedildi ama parça sunucuda zaten var (önceki deneme ulaşmış, M6): gönderilmiş say. */
    ZATEN_VAR,

    /** Sunucu kuralı reddetti (onay yok/kaldırıldı, hız sınırı, bozuk parça): bekle, yeniden dene. */
    REDDEDILDI,

    /** Ağ, zaman aşımı, oturum: bekle, yeniden dene. */
    GECICI,
}

/**
 * Parça gönderiminin yanıtı. [sunucudakiSon] yalnız [GonderimSonucu.ZATEN_VAR]'da: sunucudaki aynı
 * kimlikli parçanın `son` sırası. Önceki deneme daha az kayıtla ulaşmış olabilir; kuyruktan yalnız
 * sunucuda gerçekten olan kısım silinir (yoksa aradaki yeni noktalar kaybolurdu).
 */
data class GonderimYaniti(val sonuc: GonderimSonucu, val sunucudakiSon: Long? = null)

/** Sunucunun gönderici için gereken yüzü (RotaBulut; testte taklit). */
interface RotaSunucusu {
    /** Parçayı ve durum belgesini tek toplu yazmada gönderir (kural ikisini birlikte ister). */
    fun gonder(kimlik: String, parca: Map<String, Any?>, durum: Map<String, Any?>): GonderimYaniti

    /** Yalnız durum belgesi (kuyruk boşken durum değiştiğinde). */
    fun durumYaz(durum: Map<String, Any?>): GonderimSonucu
}

/** Gönderim anının cihaz bilgileri. */
data class Anlik(val cihazSaatiMs: Long, val pil: Int, val sarj: Boolean, val surum: Long)

/**
 * Kuyruktan sunucuya (ROTA_MIMARI §5 adım 3–4). Her [calis] çağrısı en çok bir yazma yapar ve bir
 * sonraki çağrının ne zaman yapılacağını söyler. Sunucunun hız sınırına (15 sn) uymak için iki
 * yazma arası en az [EN_AZ_ARALIK_MS]'dir. Saf: Android ve Firebase bilmez.
 *
 * [gonderimMs] merkezin gönderim aralığı (K31, varsayılan 2 dk; ücretsiz yazma kotası): iki yazma arası
 * en az budur. Kuyrukta tam bir parçalık kayıt birikmişse (ör. kapsama dışından dönüş) beklemeden,
 * hız sınırının izin verdiği sıklıkta gönderilir; böylece birikme kotayı zorlamadan erir.
 */
class Gonderici(
    private val cihaz: String,
    private val kuyruk: KuyrukDeposu,
    private val sunucu: RotaSunucusu,
    private val geri: GeriCekilme = GeriCekilme(),
    private val gonderimMs: () -> Long = { EN_AZ_ARALIK_MS },
) {
    private var sonYazmaMs = Long.MIN_VALUE / 2
    private var gonderilenDurum: String? = null
    private var sonDenemeDurumdu = false

    data class Rapor(val sonuc: GonderimSonucu?, val gonderilenKayit: Int, val sonrakiMs: Long)

    /**
     * [simdiMs] cihazın tekdüze saati (geri gitmez; SystemClock.elapsedRealtime).
     * [durumKodu] durum belgesindeki `durum`: kuyruk boşken yalnız değiştiyse yazılır.
     */
    fun calis(
        simdiMs: Long,
        anlik: Anlik,
        durumKodu: String,
        durumBelgesi: (bekleyen: Long) -> Map<String, Any?>,
    ): Rapor {
        val aralik = aralikMs()
        if (simdiMs < sonYazmaMs + aralik) return Rapor(null, 0, sonYazmaMs + aralik - simdiMs)
        if (!geri.denenebilir(simdiMs)) return Rapor(null, 0, geri.beklenecekMs(simdiMs).coerceAtLeast(1_000))
        val parca = Parca.olustur(cihaz, kuyruk.bas(Parca.EN_COK_NOKTA + Parca.EN_COK_OLAY))
        // Parça üst üste reddediliyorsa arada yalnız durum yazılır: merkez terminali "sessiz" değil,
        // "gönderemiyor, şu kadar kayıt bekliyor" olarak görür (bozuk parça kuyruğu gizlice tıkamaz).
        val yalnizDurum = parca == null || (geri.hataSayisi >= REDDE_DURUM_ESIGI && !sonDenemeDurumdu)
        if (yalnizDurum) {
            if (parca == null && durumKodu == gonderilenDurum) return Rapor(null, 0, BOS_ARALIK_MS)
            sonYazmaMs = simdiMs
            val sonuc = sunucu.durumYaz(durumBelgesi(kuyruk.sayi()))
            if (parca != null) {
                // Ret döngüsü içindeki ara durum: geri çekilmeyi ne sıfırlar ne büyütür.
                sonDenemeDurumdu = true
                return Rapor(sonuc, 0, maxOf(EN_AZ_ARALIK_MS, geri.beklenecekMs(simdiMs)))
            }
            return sonucla(sonuc, simdiMs, 0) { gonderilenDurum = durumKodu }
        }
        parca!!
        sonYazmaMs = simdiMs
        sonDenemeDurumdu = false
        val bekleyenSonra = (kuyruk.sayi() - parca.kayitlar.size).coerceAtLeast(0)
        val yanit = sunucu.gonder(
            parca.kimlik,
            parca.belge(anlik.cihazSaatiMs, anlik.pil, anlik.sarj, anlik.surum),
            durumBelgesi(bekleyenSonra),
        )
        val silinecekSon = when (yanit.sonuc) {
            GonderimSonucu.ZATEN_VAR -> minOf(parca.son, yanit.sunucudakiSon ?: (parca.ilk - 1))
            else -> parca.son
        }
        val adet = (silinecekSon - parca.ilk + 1).coerceAtLeast(0).toInt()
        return sonucla(yanit.sonuc, simdiMs, adet) {
            if (adet > 0) kuyruk.sil(parca.ilk, silinecekSon)
            // Sunucudaki parçadan sonraki kayıtlar yeni kimlikle (ilk = silinecekSon + 1) gider.
            gonderilenDurum = durumKodu
        }
    }

    private inline fun sonucla(sonuc: GonderimSonucu, simdiMs: Long, adet: Int, basarida: () -> Unit): Rapor =
        when (sonuc) {
            GonderimSonucu.TAMAM, GonderimSonucu.ZATEN_VAR -> {
                basarida()
                geri.basarili()
                // Birikmiş kayıt varsa gönderim aralığında (tam parça birikmişse hemen) devam.
                val sonraki = if (kuyruk.sayi() > 0) aralikMs() else maxOf(BOS_ARALIK_MS, aralikMs())
                Rapor(sonuc, adet, sonraki)
            }
            GonderimSonucu.REDDEDILDI, GonderimSonucu.GECICI -> {
                geri.basarisiz(simdiMs)
                // Gönderilemeyen durum yeniden denensin.
                gonderilenDurum = null
                Rapor(sonuc, 0, maxOf(EN_AZ_ARALIK_MS, geri.beklenecekMs(simdiMs)))
            }
        }

    /** İki yazma arası: tam parça bekliyorsa hız sınırı, yoksa merkezin gönderim aralığı. */
    private fun aralikMs(): Long =
        if (kuyruk.sayi() >= Parca.EN_COK_NOKTA) EN_AZ_ARALIK_MS else maxOf(EN_AZ_ARALIK_MS, gonderimMs())

    companion object {
        /** Sunucu kuralı 15 sn; saat farkları için pay. */
        const val EN_AZ_ARALIK_MS = 16_000L

        /** Bu kadar ardışık hatadan sonra parça denemeleri arasında bir kez yalnız durum yazılır. */
        const val REDDE_DURUM_ESIGI = 5

        /** Kuyruk boşken yoklama aralığı. */
        const val BOS_ARALIK_MS = 60_000L
    }
}
