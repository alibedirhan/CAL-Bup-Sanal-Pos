// Derleme hedefine göre platform bağdaştırıcıları: web paketi `platform_web.dart`,
// diğerleri (Dart testleri, desteklenmeyen platformlar) kapalı bağdaştırıcılar.
// Web paketine başka platformun kodu, diğer paketlere web JS köprüsü girmez.
export 'platform_kapali.dart' if (dart.library.js_interop) 'platform_web.dart';
