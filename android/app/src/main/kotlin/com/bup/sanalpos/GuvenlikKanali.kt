package com.bup.sanalpos

import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Dart ile tek kanal ("bup/guvenlik"). Dart karşılığı lib/data/android/kanal.dart.
 * Hatalar yalnız sabit kodla döner (GuvenlikHatasi.kod veya "hata"); kart,
 * anahtar, dosya içeriği ve istisna metni hiçbir zaman kanala/günlüğe yazılmaz.
 * Keystore işleri tek arka plan iş parçacığında, sırayla yürür.
 */
class GuvenlikKanali(
    messenger: BinaryMessenger,
    private val etkinlik: MainActivity,
) : MethodChannel.MethodCallHandler {
    private val kanal = MethodChannel(messenger, "bup/guvenlik")
    private val arka = Executors.newSingleThreadExecutor()
    private val ana = Handler(Looper.getMainLooper())
    private var bekleyenDosya: Pair<ByteArray, MethodChannel.Result>? = null

    init {
        kanal.setMethodCallHandler(this)
    }

    override fun onMethodCall(cagri: MethodCall, sonuc: MethodChannel.Result) {
        val ctx = etkinlik.applicationContext
        when (cagri.method) {
            "klasor" -> sonuc.success(ctx.noBackupFilesDir.absolutePath)
            "kasa.sifrele" -> arkada(sonuc) {
                val (iv, veri) = KasaAnahtari.sifrele(
                    ctx, cagri.metin("uid"), cagri.bayt("ekVeri"), cagri.bayt("duz"),
                    cagri.argument<Boolean>("olustur") == true,
                )
                mapOf("iv" to iv, "veri" to veri)
            }
            "kasa.coz" -> arkada(sonuc) {
                KasaAnahtari.coz(ctx, cagri.metin("uid"), cagri.bayt("ekVeri"), cagri.bayt("iv"), cagri.bayt("veri"))
            }
            "biyo.durum" -> arkada(sonuc) {
                mapOf("destekli" to BiyometriAnahtari.destekli(ctx), "acilis" to BiyometriAnahtari.acilis(ctx))
            }
            "biyo.etkinlestir" -> arkada(sonuc) { BiyometriAnahtari.etkinlestir(ctx, cagri.metin("uid")) }
            "biyo.sil" -> arkada(sonuc) { BiyometriAnahtari.sil(cagri.metin("uid")) }
            "biyo.dogrula" -> try {
                BiyometriAnahtari.dogrula(
                    etkinlik, cagri.metin("uid"), cagri.metin("baslik"), cagri.metin("aciklama"),
                ) { sonuc.success(it) }
            } catch (_: Exception) {
                sonuc.error("hata", null, null)
            }
            "dosya.kaydet" -> {
                if (bekleyenDosya != null) return sonuc.error("mesgul", null, null)
                try {
                    bekleyenDosya = cagri.metin("icerik").toByteArray(Charsets.UTF_8) to sonuc
                    etkinlik.belgeOlustur(cagri.metin("ad"))
                } catch (_: Exception) {
                    bekleyenDosya = null
                    sonuc.error("hata", null, null)
                }
            }
            else -> sonuc.notImplemented()
        }
    }

    /** Kişinin seçtiği belge (null: vazgeçti). İçerik yalnız bu adrese yazılır. */
    fun belgeSecildi(adres: Uri?) {
        val (icerik, sonuc) = bekleyenDosya ?: return
        bekleyenDosya = null
        if (adres == null) return sonuc.success("vazgecildi")
        arkada(sonuc) {
            etkinlik.contentResolver.openOutputStream(adres, "wt")?.use { it.write(icerik) }
                ?: throw GuvenlikHatasi("dosya")
            "kaydedildi"
        }
    }

    private fun arkada(sonuc: MethodChannel.Result, is_: () -> Any?) {
        arka.execute {
            val r = try {
                Result.success(is_())
            } catch (e: Exception) {
                Result.failure(e)
            }
            ana.post {
                r.fold(
                    { sonuc.success(kanalDegeri(it)) },
                    { sonuc.error((it as? GuvenlikHatasi)?.kod ?: "hata", null, null) },
                )
            }
        }
    }

    companion object {
        /**
         * Kanala gidebilecek değer: değer döndürmeyen işler (Kotlin `Unit`)
         * `null` olur. StandardMessageCodec `Unit`i taşıyamaz ve uygulamayı
         * çökertir (emülatörde yeni parmak izi eklenince "biyo.sil" ile görüldü).
         */
        fun kanalDegeri(deger: Any?): Any? = if (deger is Unit) null else deger
    }

    private fun MethodCall.metin(ad: String): String =
        argument<String>(ad) ?: throw GuvenlikHatasi("arguman")

    private fun MethodCall.bayt(ad: String): ByteArray =
        argument<ByteArray>(ad) ?: throw GuvenlikHatasi("arguman")
}
