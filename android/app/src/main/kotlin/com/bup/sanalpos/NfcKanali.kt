package com.bup.sanalpos

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Temassız kart okuma kanalı ("bup/nfc"; Dart: lib/data/android/nfc_okuyucu.dart).
 * Yalnız okuma ekranı açıkken "okuyucu kipi" açılır; kart dokununca Dart'a
 * "kart" bildirilir, Dart komutları ("apdu") tek tek gönderir. Komut ve yanıtlar
 * günlüğe yazılmaz. Protokol kuralları Dart'ta: lib/domain/emv.dart.
 */
class NfcKanali(messenger: BinaryMessenger, private val etkinlik: MainActivity) :
    MethodChannel.MethodCallHandler {
    private val kanal = MethodChannel(messenger, "bup/nfc")
    private val arka = Executors.newSingleThreadExecutor()
    private val ana = Handler(Looper.getMainLooper())
    private var kart: IsoDep? = null
    private var okuyor = false

    init {
        kanal.setMethodCallHandler(this)
    }

    private val adaptor get() = NfcAdapter.getDefaultAdapter(etkinlik)

    override fun onMethodCall(cagri: MethodCall, sonuc: MethodChannel.Result) {
        when (cagri.method) {
            "durum" -> sonuc.success(mapOf("var" to (adaptor != null), "acik" to (adaptor?.isEnabled == true)))
            "baslat" -> {
                okuyor = true
                ac()
                sonuc.success(null)
            }
            "apdu" -> {
                val komut = cagri.argument<ByteArray>("komut") ?: return sonuc.error("arguman", null, null)
                arka.execute {
                    val r = try {
                        val k = kart ?: throw IllegalStateException()
                        Result.success(k.transceive(komut))
                    } catch (e: Exception) {
                        Result.failure(e)
                    }
                    ana.post { r.fold({ sonuc.success(it) }, { sonuc.error("kart_ayrildi", null, null) }) }
                }
            }
            "bitir" -> {
                okuyor = false
                kapat()
                sonuc.success(null)
            }
            "ayarlar" -> {
                try {
                    etkinlik.startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                } catch (_: Exception) {
                    etkinlik.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                }
                sonuc.success(null)
            }
            else -> sonuc.notImplemented()
        }
    }

    /** Uygulama öne gelince okuma sürüyorsa okuyucu kipi yeniden açılır. */
    fun devam() {
        if (okuyor) ac()
    }

    private fun ac() {
        val a = adaptor ?: return
        if (!a.isEnabled) return
        val ayar = Bundle().apply { putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250) }
        a.enableReaderMode(
            etkinlik,
            ::kartBulundu,
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            ayar,
        )
    }

    private fun kapat() {
        arka.execute {
            try {
                kart?.close()
            } catch (_: Exception) {
            }
            kart = null
        }
        try {
            adaptor?.disableReaderMode(etkinlik)
        } catch (_: Exception) {
        }
    }

    /** Okuyucu kipinin iş parçacığında çağrılır. */
    private fun kartBulundu(etiket: Tag) {
        arka.execute {
            val olay = try {
                val k = IsoDep.get(etiket) ?: throw IllegalArgumentException()
                k.connect()
                k.timeout = 5000
                kart?.close()
                kart = k
                "kart"
            } catch (_: Exception) {
                "kart_degil"
            }
            ana.post { kanal.invokeMethod(olay, null) }
        }
    }
}
