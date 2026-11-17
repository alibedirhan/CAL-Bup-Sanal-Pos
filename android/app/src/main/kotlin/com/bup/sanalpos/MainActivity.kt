package com.bup.sanalpos

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import com.bup.sanalpos.rota.RotaHizmeti
import com.bup.sanalpos.rota.RotaKanali
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// Biyometri penceresi FragmentActivity ister.
class MainActivity : FlutterFragmentActivity() {
    private var kanal: GuvenlikKanali? = null
    private var nfc: NfcKanali? = null
    private var rota: RotaKanali? = null

    // "Kaydet" penceresi (gün sonu CSV). Etkinlik başlamadan kaydedilmelidir.
    private val belge = registerForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) {
        kanal?.belgeSecildi(it)
    }

    fun belgeOlustur(ad: String) = belge.launch(ad)

    // Konum kurulumu (rota, yalnız yönetici ekranından): izin penceresi.
    private val konumIzni = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
        rota?.izinSonucu(it)
    }

    fun konumIzniIste(izin: String) = konumIzni.launch(izin)

    override fun onCreate(savedInstanceState: Bundle?) {
        // Ekran görüntüsü, ekran kaydı ve "son uygulamalar" önizlemesi kapalı
        // (kart ve cari bilgisi). Yalnız hata ayıklama derlemesinde açık: test
        // ekran görüntüleri için; dağıtılan sürüm her zaman korumalıdır.
        if (!BuildConfig.DEBUG) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        super.onCreate(savedInstanceState)
        // Rota (docs/ROTA_MIMARI.md M12): hizmet çalışmıyorsa başlar. Yapılandırma ya da konum
        // izni yoksa hiçbir şey yapmaz; ekranda hiçbir şey görünmez (K24).
        RotaHizmeti.baslat(this, "uygulama")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        kanal = GuvenlikKanali(flutterEngine.dartExecutor.binaryMessenger, this)
        nfc = NfcKanali(flutterEngine.dartExecutor.binaryMessenger, this)
        rota = RotaKanali(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    override fun onResume() {
        super.onResume()
        nfc?.devam()
    }
}
