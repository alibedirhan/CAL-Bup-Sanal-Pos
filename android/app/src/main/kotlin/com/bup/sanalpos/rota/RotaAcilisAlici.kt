package com.bup.sanalpos.rota

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Telefon açılınca ve uygulama güncellenince rota hizmetini başlatır (M12). Yalnız sistemin korumalı
 * yayınlarına bakar; başka bir uygulama bu yayınları gönderemez. İzin yoksa hiçbir şey yapmaz.
 */
class RotaAcilisAlici : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        when (i.action) {
            Intent.ACTION_BOOT_COMPLETED -> RotaHizmeti.baslat(c, RotaHizmeti.NEDEN_ACILIS)
            Intent.ACTION_MY_PACKAGE_REPLACED -> RotaHizmeti.baslat(c, "guncelleme")
        }
    }
}
