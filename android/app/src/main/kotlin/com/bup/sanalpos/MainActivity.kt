package com.bup.sanalpos

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// Biyometri penceresi FragmentActivity ister.
class MainActivity : FlutterFragmentActivity() {
    private var kanal: GuvenlikKanali? = null

    // "Kaydet" penceresi (gün sonu CSV). Etkinlik başlamadan kaydedilmelidir.
    private val belge = registerForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) {
        kanal?.belgeSecildi(it)
    }

    fun belgeOlustur(ad: String) = belge.launch(ad)

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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        kanal = GuvenlikKanali(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
