package com.bup.sanalpos.rota

import android.content.Context

/**
 * Son bilinen merkez ayarı (gizli değil). Terminal ağsız açıldığında (ör. kapsama dışında yeniden
 * başlatma) merkezin son "takip açık" kararı sürsün diye saklanır; ağ gelince sunucudaki geçerli olur.
 */
class AyarDeposu(context: Context) {
    private val p = context.applicationContext.getSharedPreferences("rota", Context.MODE_PRIVATE)

    var ayar: TakipAyari
        get() = TakipAyari(
            aktif = p.getBoolean("aktif", false),
            takip = p.getBoolean("takip", false),
            hareketSn = p.getInt("hareketSn", TakipAyari.KAPALI.hareketSn),
            durgunSn = p.getInt("durgunSn", TakipAyari.KAPALI.durgunSn),
            depoSn = p.getInt("depoSn", TakipAyari.KAPALI.depoSn),
            gonderimSn = p.getInt("gonderimSn", TakipAyari.VARSAYILAN_GONDERIM_SN),
        )
        set(a) {
            p.edit().putBoolean("aktif", a.aktif).putBoolean("takip", a.takip).putInt("hareketSn", a.hareketSn)
                .putInt("durgunSn", a.durgunSn).putInt("depoSn", a.depoSn).putInt("gonderimSn", a.gonderimSn).apply()
        }

    var depolar: List<Depo>
        get() = p.getString("depolar", null).orEmpty().split(";").mapNotNull { s ->
            val d = s.split(",")
            if (d.size != 3) return@mapNotNull null
            Depo.listeden(listOf(mapOf("en" to d[0].toDoubleOrNull(), "boy" to d[1].toDoubleOrNull(), "yaricap" to d[2].toDoubleOrNull())))
                .firstOrNull()
        }
        set(l) {
            p.edit().putString("depolar", l.joinToString(";") { "${it.enlem},${it.boylam},${it.yaricap}" }).apply()
        }

    /** Başvuru bu kimlikle bırakıldı mı (her açılışta sunucuya sormamak için). */
    var basvuruKimligi: String?
        get() = p.getString("basvuru", null)
        set(v) {
            p.edit().putString("basvuru", v).apply()
        }

    /** Saat referansı (M21): hizmet yeniden başlasa da (bekçi) aynı açılışta geçerli kalsın. */
    var saatReferansi: SaatFarki.Referans?
        get() = if (!p.contains("saatGercek")) null else SaatFarki.Referans(
            p.getLong("saatGercek", 0), p.getLong("saatTekduze", 0), p.getInt("saatAcilis", -1),
        )
        set(r) {
            if (r == null) {
                p.edit().remove("saatGercek").remove("saatTekduze").remove("saatAcilis").apply()
            } else {
                p.edit().putLong("saatGercek", r.gercekMs).putLong("saatTekduze", r.tekduzeMs)
                    .putInt("saatAcilis", r.acilis).apply()
            }
        }

    /** Son konumun açık olup olmadığı (açılışta "konum kapandı/açıldı" olayı için). */
    var konumAcikti: Boolean?
        get() = if (p.contains("konumAcik")) p.getBoolean("konumAcik", true) else null
        set(v) {
            if (v == null) p.edit().remove("konumAcik").apply() else p.edit().putBoolean("konumAcik", v).apply()
        }

    /** Km sayacı (M23): hizmet yeniden başlasa da toplam sürsün. Her kayıtta yazılır (en sık 15 sn'de bir). */
    var kmDurumu: KmSayaci.Durum?
        get() = if (!p.contains("kmToplam")) null else KmSayaci.Durum(
            java.lang.Double.longBitsToDouble(p.getLong("kmToplam", 0)), p.getLong("kmZaman", 0),
            java.lang.Double.longBitsToDouble(p.getLong("kmEn", 0)), java.lang.Double.longBitsToDouble(p.getLong("kmBoy", 0)),
            java.lang.Double.longBitsToDouble(p.getLong("kmDog", 0)),
        )
        set(d) {
            if (d == null) return
            p.edit().putLong("kmToplam", d.toplamM.toRawBits()).putLong("kmZaman", d.zaman)
                .putLong("kmEn", d.enlem.toRawBits()).putLong("kmBoy", d.boylam.toRawBits())
                .putLong("kmDog", d.dogruluk.toRawBits()).apply()
        }

    /** Merkeze en son bildirilen kurulum durumu (yalnız değişince yeniden bildirilir). */
    var sonKurulum: String?
        get() = p.getString("kurulum", null)
        set(v) {
            p.edit().putString("kurulum", v).apply()
        }

    var sonKurulumZamani: Long
        get() = p.getLong("kurulumZamani", 0)
        set(v) {
            p.edit().putLong("kurulumZamani", v).apply()
        }
}
