import 'dart:async';
import 'package:flutter/material.dart';
import 'application/pos_servisi.dart';
import 'data/demo_deposu.dart';
import 'data/demo_islemleri.dart';
import 'application/tahsilat_servisi.dart';
import 'bilesim/platform.dart';
import 'ui/ana_ekran.dart';
import 'ui/karsilama.dart';
import 'ui/oturum_modeli.dart';
import 'ui/tema.dart';
import 'application/hesap_portu.dart';
import 'domain/kullanici.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BupPosApp extends StatefulWidget {
  const BupPosApp({
    super.key,
    this.deneme = true,
    this.servis,
    this.bostaSure = const Duration(minutes: 10),
    this.donusSuresi = const Duration(minutes: 5),
    this.kullanici,
    this.hesap,
    this.yonetim,
    this.canliKilit,
  });
  final bool deneme;
  final PosServisi? servis;
  final Duration bostaSure, donusSuresi;
  final Kullanici? kullanici;
  final HesapPortu? hesap;
  final YonetimPortu? yonetim;
  final VoidCallback? canliKilit;
  @override
  State<BupPosApp> createState() => _BupPosAppState();
}

class _BupPosAppState extends State<BupPosApp> with WidgetsBindingObserver {
  late final OturumModeli _model;
  final _navigator = GlobalKey<NavigatorState>();
  Timer? _zamanlayici;
  DateTime? _gizlenme;
  bool _basladi = false;
  StreamSubscription<void>? _kutu;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _basladi = !widget.deneme && widget.servis != null;
    _model = OturumModeli(
      widget.servis ??
          PosServisi(
            depo: DemoDeposu(),
            baglanti: DemoPosBaglantisi(),
            kullaniciId: DemoDeposu.kullanici,
            tahsilat: TahsilatServisi(
              depo: DemoIslemDeposu(),
              kullaniciId: DemoDeposu.kullanici,
              kullaniciAdi: 'Deneme Kullanıcısı',
              indirici: platformBaglantilari.indirici,
            ),
          ),
      deneme: widget.deneme,
    );
    // Canlı kipte demo deposundan liste dahi istenmez.
    if (widget.deneme || widget.servis != null) unawaited(_model.yukle());
    if (_basladi) _etkilesim();
    // DenizPay sonuç sayfasının bu telefona bıraktığı sonuçlar: açılışta, başka
    // sekmede eklenince ve sekmeye dönüşte yazılır (oturum yalnız bu sekmede).
    final tahsilat = _model.servis.tahsilat;
    if (tahsilat != null && tahsilat.kutu.destekli) {
      _kutu = tahsilat.kutu.degisimler.listen((_) => _kutuyuIsle());
      unawaited(_kutuyuIsle());
    }
  }

  Future<void> _kutuyuIsle() async {
    final sonuclar = await _model.servis.tahsilat!.kutuyuIsle();
    if (!mounted || sonuclar.isEmpty) return;
    // Hata varsa o görünür; yoksa son kayıt.
    final not = sonuclar.lastWhere(
      (s) => !s.tamam,
      orElse: () => sonuclar.last,
    );
    _model.tahsilatBildir(
      sonuclar.length > 1 && not.tamam
          ? '${sonuclar.length} DenizPay sonucu kaydedildi. Son: ${not.mesaj}'
          : not.mesaj,
    );
  }

  void _etkilesim() {
    if (!_basladi || _model.kilitli) return;
    _zamanlayici?.cancel();
    _zamanlayici = Timer(
      widget.bostaSure,
      () => _kilitle(bekleyenIsiSil: false),
    );
  }

  /// "Ekranı kilitle" bekleyen kart işini de siler; sekme değişimi ve boşta
  /// kalma silmez (kullanıcı DenizPay sekmesinde yer imini kullanacak).
  void _kilitle({bool bekleyenIsiSil = true}) {
    if (!_basladi || _model.kilitli) return;
    _zamanlayici?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _model.kilitle(bekleyenIsiSil: bekleyenIsiSil);
    widget.canliKilit?.call();
  }

  /// Kullanıcı kararı (21 Ekim): DenizPay sekmesine geçip `donusSuresi` içinde
  /// dönünce şifre sorulmaz, ekran olduğu gibi kalır; daha geç dönüşte kilit.
  /// Gizliyken saat ilerlemeyebilir (tarayıcı betikleri durdurur); bu yüzden
  /// süre dönüşte, gizlenme anından ölçülür. Boşta kilidi ayrıca geçerlidir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _kilitle(bekleyenIsiSil: false);
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _gizlenme ??= _model.servis.saat();
    } else if (state == AppLifecycleState.resumed) {
      final gizlenme = _gizlenme;
      _gizlenme = null;
      if (gizlenme == null) return;
      final fark = _model.servis.saat().difference(gizlenme);
      if (fark.isNegative || fark >= widget.donusSuresi) {
        _kilitle(bekleyenIsiSil: false);
      } else {
        _etkilesim();
        // Kilitlenince yazılmaz: kilit açılınca yeni ekran yazar ve sonucu gösterir.
        if (_kutu != null) unawaited(_kutuyuIsle());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zamanlayici?.cancel();
    _kutu?.cancel();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BUP Sanal POS',
    debugShowCheckedModeBanner: false,
    theme: posTemasi(),
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    navigatorKey: _navigator,
    builder: (context, child) => Listener(
      onPointerDown: (_) => _etkilesim(),
      onPointerSignal: (_) => _etkilesim(),
      child: Focus(
        // Yalnız alt öğelerin klavye olaylarını dinler; odak hedefi değildir.
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, _) {
          _etkilesim();
          return KeyEventResult.ignored;
        },
        child: ListenableBuilder(
          listenable: _model,
          builder: (context, _) => Stack(
            children: [
              Offstage(offstage: _model.kilitli, child: child!),
              if (_model.kilitli)
                Karsilama(
                  kilitli: true,
                  devam: () {
                    _model.denemeyeDon();
                    _etkilesim();
                  },
                ),
            ],
          ),
        ),
      ),
    ),
    home: !widget.deneme && widget.servis == null
        ? Karsilama(canliKapali: true, devam: () {})
        : !_basladi
        ? Karsilama(
            devam: () {
              setState(() => _basladi = true);
              _etkilesim();
            },
          )
        : AnaEkran(
            model: _model,
            kilitle: _kilitle,
            kullanici: widget.kullanici,
            hesap: widget.hesap,
            yonetim: widget.yonetim,
          ),
  );
}
