import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../application/denizpay_oturumu.dart';
import '../../domain/denizpay.dart';
import '../../domain/pos_girisi.dart';
import 'denizpay_betigi.dart';

/// Uygulama içi DenizPay için Android WebView (docs/ANDROID_PLANI.md §3).
/// Gezinme [DenizPayAdresi.karar] ile süzülür; betik yalnız DenizPay kökeninde
/// ve yalnız istendiğinde çalışır. Dosya/içerik erişimi, konum, kamera/mikrofon
/// izinleri, dosya seçme ve karışık içerik kapalı; sertifika hatasında sayfa
/// açılmaz. Sayfa içeriği, kart veya şifre günlüğe yazılmaz.
class AndroidDenizPayTarayicisi implements DenizPayTarayicisi {
  AndroidDenizPayTarayicisi(this.adres, {required this.yuklendi}) {
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            final u = Uri.tryParse(r.url);
            return u != null && adres.karar(u) != Gezinme.engel
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            final u = Uri.tryParse(url);
            if (u != null) unawaited(yuklendi(u));
          },
          onSslAuthError: (e) => unawaited(e.cancel()),
          onHttpAuthRequest: (r) => r.onCancel(),
        ),
      );
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      unawaited(AndroidWebViewController.enableDebugging(kDebugMode));
      unawaited(p.setAllowFileAccess(false));
      unawaited(p.setAllowContentAccess(false));
      unawaited(p.setGeolocationEnabled(false));
      unawaited(p.setMixedContentMode(MixedContentMode.neverAllow));
      unawaited(p.setMediaPlaybackRequiresUserGesture(true));
      unawaited(p.setOnPlatformPermissionRequest((r) => r.deny()));
      unawaited(p.setOnShowFileSelector((_) async => const <String>[]));
    }
  }

  final DenizPayAdresi adres;
  final Future<void> Function(Uri adres) yuklendi;
  late final WebViewController _c;

  Widget get gorunum => WebViewWidget(controller: _c);

  @override
  Future<void> temizle() async {
    await WebViewCookieManager().clearCookies();
    await _c.clearCache();
    await _c.clearLocalStorage();
    await _c.loadRequest(Uri.parse('about:blank'));
  }

  @override
  Future<void> girisYap(Uri giris, PosGirisBilgisi g) async {
    if (!adres.denizPayMi(giris)) throw StateError('giris');
    // Alanlar web/pos_giris.js ile aynı; boş __VIEWSTATE ASP.NET'in isteği
    // giriş gönderimi olarak işlemesi içindir.
    final govde = Uri(
      queryParameters: {
        '__VIEWSTATE': '',
        'lvergino': g.vergiNo,
        'lkullaniciadi': g.kullanici,
        'lsifre': g.sifre,
        'btngiris': 'Giriş Yap',
      },
    ).query;
    await _c.loadRequest(
      giris,
      method: LoadRequestMethod.post,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: Uint8List.fromList(utf8.encode(govde)),
    );
  }

  /// Açık sayfa hâlâ DenizPay ise betiği çalıştırır (yarışta banka sayfasına
  /// geçilmişse çalıştırmaz); betik ayrıca kökeni kendisi denetler.
  Future<Map<String, Object?>?> _calistir(Map<String, Object?> istek) async {
    final simdiki = Uri.tryParse(await _c.currentUrl() ?? '');
    if (simdiki == null || !adres.denizPayMi(simdiki)) return null;
    final betik = denizPayBetigi.replaceAll(
      '__KOKEN__',
      adres.koken.toString().replaceAll(RegExp(r'/$'), ''),
    );
    Object r = await _c.runJavaScriptReturningResult(
      '$betik(${jsonEncode(istek)})',
    );
    // Android sonucu JSON değeri olarak verir: metin tırnaklı gelebilir.
    if (r is String && r.startsWith('"')) r = jsonDecode(r) as Object;
    final d = r is String ? jsonDecode(r) : null;
    return d is Map ? d.cast<String, Object?>() : null;
  }

  @override
  Future<Object?> ozetAl() async {
    final d = await _calistir(const {'tur': 'ozet'});
    return d == null || d.containsKey('hata') ? null : d;
  }

  @override
  Future<String> kartiYaz({
    required String numara,
    required String sahibi,
    required int ay,
    required int yil,
    required String kimlikNo,
  }) async {
    final d = await _calistir({
      'tur': 'yaz',
      'kart': {
        'numara': numara,
        'ad': sahibi,
        'ay': ay,
        'yil': yil,
        'kimlikNo': kimlikNo,
      },
    });
    final s = d?['sonuc'];
    return s is String ? s : 'sayfa';
  }
}
