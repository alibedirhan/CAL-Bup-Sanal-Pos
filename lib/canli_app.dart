import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'application/pos_servisi.dart';
import 'data/firebase_hesap.dart';
import 'data/firebase_yonetim.dart';
import 'data/firestore_deposu.dart';
import 'domain/hata.dart';
import 'domain/kullanici.dart';
import 'data/secim_kontrolu.dart';
import 'data/cihaz_kart_kasasi.dart';
import 'data/pos_giris_kapisi.dart';
import 'ui/giris_sayfasi.dart';
import 'ui/tema.dart';

class CanliApp extends StatefulWidget {
  const CanliApp({super.key});
  @override
  State<CanliApp> createState() => _CanliAppState();
}

class _CanliAppState extends State<CanliApp> {
  late final Future<FirebaseHesap> _hazir = _baslat();
  Future<FirebaseHesap> _baslat() async {
    const emulator = bool.fromEnvironment('BUP_EMULATOR');
    const proje = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (proje.isEmpty || (emulator && !proje.startsWith('demo-'))) {
      throw const PosHatasi(
        'kurulum',
        'Uygulama yapılandırması eksik. Yöneticiyle görüşün.',
      );
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: proje,
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      ),
    );
    final auth = FirebaseAuth.instance, db = FirebaseFirestore.instance;
    db.settings = const Settings(persistenceEnabled: false);
    if (emulator) {
      await auth.useAuthEmulator('127.0.0.1', 9098);
      db.useFirestoreEmulator('127.0.0.1', 8088);
    }
    final hesap = FirebaseHesap(auth, db);
    await hesap.hazirla();
    return hesap;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _hazir,
    builder: (context, snapshot) {
      if (snapshot.hasData) return _HesapKapisi(hesap: snapshot.data!);
      if (snapshot.hasError) {
        final e = snapshot.error;
        debugPrint(
          'POS başlangıç hatası: ${e is FirebaseException ? e.code : e.runtimeType}',
        );
      }
      return MaterialApp(
        theme: posTemasi(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? const Text(
                      'Bağlantı kurulamadı. Sayfayı yenileyip tekrar deneyin.',
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

class _HesapKapisi extends StatefulWidget {
  const _HesapKapisi({required this.hesap});
  final FirebaseHesap hesap;
  @override
  State<_HesapKapisi> createState() => _HesapKapisiState();
}

class _HesapKapisiState extends State<_HesapKapisi> {
  StreamSubscription<String?>? _auth;
  StreamSubscription<Kullanici?>? _profil;
  Kullanici? _kullanici;
  bool _hazir = false, _kilitli = false, _kontrol = false;
  String? _hata;
  int _nesil = 0;
  @override
  void initState() {
    super.initState();
    _auth = widget.hesap.degisimler.listen((uid) {
      _nesil++;
      unawaited(_profil?.cancel());
      setState(() {
        _kullanici = null;
        _kilitli = false;
        _hata = null;
        _hazir = true;
        _kontrol = uid != null;
      });
      if (uid != null) {
        _profil = widget.hesap.profilIzle().listen(
          (k) {
            if (!mounted) return;
            setState(() {
              _kontrol = false;
              _kullanici = k?.aktif == true ? k : null;
              _hata = k?.aktif == true
                  ? null
                  : 'Hesabının erişimi kapalı. Yöneticiyle görüş.';
            });
          },
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _kontrol = false;
                _kullanici = null;
                _hata = e is PosHatasi
                    ? e.mesaj
                    : 'Erişim doğrulanamadı. İnternet bağlantını kontrol et.';
              });
            }
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _profil?.cancel();
    super.dispose();
  }

  Future<void> _ac(String parola) async {
    final nesil = _nesil;
    await widget.hesap.yenidenDogrula(parola);
    final k = await widget.hesap.profil();
    if (!k.aktif) throw const PosHatasi('yetki', 'Bu hesaba erişim kapalı.');
    if (mounted && nesil == _nesil) {
      setState(() {
        _kilitli = false;
        _kullanici = k;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kullanici;
    if (k != null && !_kilitli) {
      return BupPosApp(
        key: ValueKey('${k.id}-$_nesil'),
        deneme: false,
        servis: PosServisi(
          depo: FirestoreDeposu(widget.hesap.db),
          baglanti: const SecimKontrolu(),
          kullaniciId: k.id,
          kartKasasi: const CihazKartKasasi(),
          girisKapisi: const CihazPosGirisKapisi(),
        ),
        kullanici: k,
        hesap: widget.hesap,
        yonetim: k.yonetici
            ? FirebaseYonetim(
                widget.hesap.auth,
                widget.hesap.db,
                emulator: const bool.fromEnvironment('BUP_EMULATOR'),
              )
            : null,
        canliKilit: () => setState(() => _kilitli = true),
      );
    }
    return MaterialApp(
      theme: posTemasi(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: !_hazir || _kontrol
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _hata != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_hata!),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.hesap.cikis,
                        child: const Text('Giriş ekranına dön'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : GirisSayfasi(
              hesap: widget.hesap,
              eposta: k?.eposta,
              kilitli: _kilitli,
              giris: _kilitli ? _ac : null,
            ),
    );
  }
}
