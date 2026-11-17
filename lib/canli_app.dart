import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'bilesim/platform.dart';
import 'application/biyometrik_kilit.dart';
import 'application/pos_servisi.dart';
import 'application/surum_denetimi.dart';
import 'data/firebase_hesap.dart';
import 'data/firebase_yonetim.dart';
import 'data/firestore_deposu.dart';
import 'data/firestore_surum.dart';
import 'domain/hata.dart';
import 'domain/kullanici.dart';
import 'domain/surum.dart';
import 'data/secim_kontrolu.dart';
import 'data/firestore_islemleri.dart';
import 'application/tahsilat_servisi.dart';
import 'ui/giris_sayfasi.dart';
import 'ui/guncelleme.dart';
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
      // Android emülatöründe bilgisayarın yerel adresi 10.0.2.2'dir.
      const host = String.fromEnvironment(
        'BUP_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await auth.useAuthEmulator(host, 9098);
      db.useFirestoreEmulator(host, 8088);
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
  static final _platform = platformBaglantilari;
  StreamSubscription<String?>? _auth;
  StreamSubscription<Kullanici?>? _profil;
  Kullanici? _kullanici;
  bool _hazir = false, _kilitli = false, _kontrol = false;
  // İlk olay: uygulama açılışında kalıcı oturumdan gelen hesap (Android). Sonraki
  // olaylar şifreyle giriş veya çıkıştır.
  bool _ilkOlay = true, _biyometri = false;
  String? _hata;
  int _nesil = 0;
  String? _sonUid;
  SurumSonucu _surum = SurumSonucu.guncel;
  late final _surumDenetimi = SurumDenetimi(
    uygulama: _platform.uygulamaSurumu,
    ayar: FirestoreSurumAyari(widget.hesap.db),
  );
  @override
  void initState() {
    super.initState();
    _auth = widget.hesap.degisimler.listen((uid) {
      // Çıkış veya hesap değişiminde önceki hesabın bekleyen kart işi kalmaz;
      // aynı hesabın sayfa yenilemesi işi silmez.
      if (uid == null || (_sonUid != null && uid != _sonUid)) {
        _platform.doldurma.temizle();
      }
      // DenizPay girişleri (sır yok) yalnız bu sekmede çıkışta silinir. Yeni açılan
      // sekme de önce oturumsuz başlar; o an silinirse DenizPay'de süren ödemenin
      // sonucu cariye bağlanamaz. Giriş yapılınca başka hesabın girişleri atılır.
      if (uid == null && _sonUid != null) _platform.acikGiris.temizle();
      if (uid != null) _platform.acikGiris.yalniz(uid);
      // Çıkıştan sonra yeniden şifre gerekir; yeni giriş şifreyle yapılmıştır.
      final onceki = _sonUid;
      if (onceki != null && uid != onceki) {
        unawaited(_platform.biyometri.unut(onceki));
      }
      final acilis = _ilkOlay && uid != null && _platform.acilistaKilit;
      if (uid != null && !_ilkOlay) {
        unawaited(_platform.biyometri.sifreDogrulandi(uid));
      }
      _ilkOlay = false;
      _sonUid = uid;
      _nesil++;
      unawaited(_profil?.cancel().catchError((Object _) {}));
      setState(() {
        _kullanici = null;
        _kilitli = acilis;
        _biyometri = false;
        _hata = null;
        _hazir = true;
        _kontrol = uid != null;
      });
      if (acilis) _biyometriyiDenetle();
      if (uid != null) {
        _profil = widget.hesap.profilIzle().listen(
          (k) {
            if (!mounted) return;
            if (_kullanici == null && k?.aktif == true) _surumuDenetle();
            setState(() {
              _kontrol = false;
              _kullanici = k?.aktif == true ? k : null;
              if (_kullanici == null) {
                _platform.doldurma.temizle();
                _platform.acikGiris.temizle();
              }
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
    _auth?.cancel().catchError((Object _) {});
    _profil?.cancel().catchError((Object _) {});
    super.dispose();
  }

  Future<void> _ac(String parola) async {
    final nesil = _nesil;
    await widget.hesap.yenidenDogrula(parola);
    final k = await _profilAc(nesil);
    if (k != null) unawaited(_platform.biyometri.sifreDogrulandi(k.id));
  }

  /// Kilit açıldıktan sonra hesap yetkisi her zaman sunucudan yeniden okunur.
  Future<Kullanici?> _profilAc(int nesil) async {
    final k = await widget.hesap.profil();
    if (!k.aktif) throw const PosHatasi('yetki', 'Bu hesaba erişim kapalı.');
    if (!mounted || nesil != _nesil) return null;
    setState(() {
      _kilitli = false;
      _kullanici = k;
    });
    _surumuDenetle();
    return k;
  }

  /// Android: açılışta ve kilit açılınca sunucudaki en düşük/son sürüme bakılır.
  /// Web'de ve denetlenemezse uygulama olduğu gibi açılır.
  void _surumuDenetle() {
    final nesil = _nesil;
    unawaited(
      _surumDenetimi.denetle().then((s) {
        if (mounted && nesil == _nesil) setState(() => _surum = s);
      }),
    );
  }

  /// Parmak izi/yüz. Dönen metin ekranda gösterilir; `null`: söylenecek yok.
  Future<String?> _biyometriyleAc() async {
    final nesil = _nesil, uid = _sonUid;
    if (uid == null) return null;
    switch (await _platform.biyometri.dogrula(uid)) {
      case BiyometriSonucu.tamam:
        await _profilAc(nesil);
        return null;
      case BiyometriSonucu.iptal:
        return null;
      case BiyometriSonucu.sifreGerekli:
        if (mounted && nesil == _nesil) setState(() => _biyometri = false);
        return 'Parmak iziyle açma bu kez kullanılamıyor. Hesap şifreni yaz.';
      case BiyometriSonucu.hata:
        return 'Parmak izi doğrulanamadı. Yeniden dene ya da şifreni yaz.';
    }
  }

  void _kilitle() {
    setState(() {
      _kilitli = true;
      _biyometri = false;
    });
    _biyometriyiDenetle();
  }

  /// Kilit ekranında biyometri düğmesi yalnız gerçekten kullanılabiliyorsa görünür.
  void _biyometriyiDenetle() {
    final nesil = _nesil, uid = _sonUid;
    if (uid == null) return;
    unawaited(
      _platform.biyometri.kullanilabilir(uid).then((kullanilir) {
        if (mounted && nesil == _nesil && _kilitli) {
          setState(() => _biyometri = kullanilir);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = _kullanici;
    final surum = _surum.bilgi;
    if (k != null &&
        !_kilitli &&
        surum != null &&
        _surum.durum == SurumDurumu.guncellemeGerekli) {
      return MaterialApp(
        theme: posTemasi(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: GuncellemeSayfasi(bilgi: surum, cikis: widget.hesap.cikis),
      );
    }
    if (k != null && !_kilitli) {
      return BupPosApp(
        key: ValueKey('${k.id}-$_nesil'),
        deneme: false,
        servis: PosServisi(
          depo: FirestoreDeposu(widget.hesap.db),
          baglanti: const SecimKontrolu(),
          kullaniciId: k.id,
          kartKasasi: _platform.kartKasasi,
          girisKapisi: _platform.girisKapisi,
          doldurma: _platform.doldurma,
          uygulamaIciDenizPay: _platform.denizPayAcici != null,
          tahsilat: TahsilatServisi(
            depo: FirestoreIslemDeposu(widget.hesap.db),
            kullaniciId: k.id,
            kullaniciAdi: k.ad,
            acikGiris: _platform.acikGiris,
            indirici: _platform.indirici,
            kutu: _platform.sonucKutusu,
          ),
        ),
        kullanici: k,
        denizPayAcici: _platform.denizPayAcici,
        hesap: widget.hesap,
        yonetim: k.yonetici
            ? FirebaseYonetim(
                widget.hesap.auth,
                widget.hesap.db,
                emulator: const bool.fromEnvironment('BUP_EMULATOR'),
              )
            : null,
        canliKilit: _kilitle,
        guncelleme: _surum.durum == SurumDurumu.guncellemeVar ? surum : null,
        rotaKurulumu: k.yonetici ? _platform.rotaKurulumu : null,
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
              biyometri: _kilitli && _biyometri ? _biyometriyleAc : null,
            ),
    );
  }
}
