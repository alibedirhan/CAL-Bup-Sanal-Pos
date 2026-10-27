// Derleme hedefine göre platform bağdaştırıcıları: web paketi `platform_web.dart`,
// Android (ve Dart testleri, dart:io) `platform_android.dart` — o da Android
// dışında çalışırken kapalı bağdaştırıcıları verir. Web paketine Android kodu,
// Android paketine web JS köprüsü girmez.
export 'platform_kapali.dart'
    if (dart.library.js_interop) 'platform_web.dart'
    if (dart.library.io) 'platform_android.dart';
