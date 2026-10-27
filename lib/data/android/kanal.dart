import 'package:flutter/services.dart';

/// Android güvenlik kanalı; Kotlin karşılığı `GuvenlikKanali.kt`. Hatalar yalnız
/// sabit kodla gelir (`PlatformException.code`); ayrıntı taşımaz.
const guvenlikKanali = MethodChannel('bup/guvenlik');

/// Kişisel/yerel verinin klasörü: Android yedeğine ve cihaz aktarımına girmez
/// (`noBackupFilesDir`; ayrıca `veri_cikarma.xml` bütün yedeği kapatır).
Future<String> yedeksizKlasor() async =>
    await guvenlikKanali.invokeMethod<String>('klasor') ??
    (throw StateError('klasor'));
