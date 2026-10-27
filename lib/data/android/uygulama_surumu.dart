import '../../application/surum_denetimi.dart';
import 'kanal.dart';

/// Kurulu APK'nın `versionCode`'u (Kotlin `BuildConfig`); derlemede sabittir.
class AndroidUygulamaSurumu implements UygulamaSurumuPortu {
  const AndroidUygulamaSurumu();
  @override
  Future<int?> kod() => guvenlikKanali.invokeMethod<int>('surum');
}
