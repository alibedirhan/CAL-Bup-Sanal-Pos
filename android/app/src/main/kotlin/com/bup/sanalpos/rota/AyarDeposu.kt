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

    /** Son konumun açık olup olmadığı (açılışta "konum kapandı/açıldı" olayı için). */
    var konumAcikti: Boolean?
        get() = if (p.contains("konumAcik")) p.getBoolean("konumAcik", true) else null
        set(v) {
            if (v == null) p.edit().remove("konumAcik").apply() else p.edit().putBoolean("konumAcik", v).apply()
        }
}
