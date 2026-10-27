package com.bup.sanalpos

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
