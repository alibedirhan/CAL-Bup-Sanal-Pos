import 'dart:async';
import 'package:flutter/material.dart';
import 'application/pos_servisi.dart';
import 'data/demo_deposu.dart';
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
    this.kullanici,
    this.hesap,
    this.yonetim,
    this.canliKilit,
  });
  final bool deneme;
  final PosServisi? servis;
  final Duration bostaSure;
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
  bool _basladi = false;
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
          ),
      deneme: widget.deneme,
    );
    // Canlı kipte demo deposundan liste dahi istenmez.
    if (widget.deneme || widget.servis != null) unawaited(_model.yukle());
    if (_basladi) _etkilesim();
  }

  void _etkilesim() {
    if (!_basladi || _model.kilitli) return;
    _zamanlayici?.cancel();
    _zamanlayici = Timer(widget.bostaSure, _kilitle);
  }

  void _kilitle() {
    if (!_basladi || _model.kilitli) return;
    _zamanlayici?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _model.kilitle();
    widget.canliKilit?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _kilitle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zamanlayici?.cancel();
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
