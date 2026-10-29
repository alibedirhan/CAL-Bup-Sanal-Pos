import 'dart:async';
import 'package:flutter/material.dart';
import '../application/tahsilat_servisi.dart';
import '../domain/gun_sonu.dart';
import '../domain/hata.dart';
import '../domain/tahsilat.dart';
import 'gun_sonu_parcalari.dart';
import 'ortak.dart';
import 'tema.dart';

/// Türkiye saatiyle günlük tahsilat özeti. Kayıtlar değiştirilemediği için
/// geçmiş günler kesindir; bugünün gün sonu 24:00'te kendiliğinden kapanır.
class GunSonuSayfasi extends StatefulWidget {
  const GunSonuSayfasi({
    super.key,
    required this.servis,
    this.yonetici = false,
    this.deneme = false,
    this.uygulamaIci = false,
  });
  final TahsilatServisi servis;
  final bool yonetici, deneme;

  /// DenizPay uygulama içinde açılıyor (Android): yer imi yok.
  final bool uygulamaIci;
  @override
  State<GunSonuSayfasi> createState() => _GunSonuSayfasiState();
}

class _GunSonuSayfasiState extends State<GunSonuSayfasi> {
  late Gun _gun = widget.servis.bugun;
  bool _herkes = false, _yukleniyor = false;
  GunSonu? _sonuc;
  String? _hata;
  int _istek = 0;
  Timer? _gece;

  @override
  void initState() {
    super.initState();
    unawaited(_yukle());
    _geceyiKur();
  }

  /// Açık kalan ekranda gün değişince "devam ediyor" yazısı kendiliğinden kapanır.
  void _geceyiKur() {
    _gece?.cancel();
    final kalan = widget.servis.bugun.bitis.difference(widget.servis.saat());
    _gece = Timer(kalan + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _geceyiKur();
    });
  }

  @override
  void dispose() {
    _gece?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    final istek = ++_istek;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final sonuc = await widget.servis.gunSonu(_gun, herkes: _herkes);
      if (mounted && istek == _istek) setState(() => _sonuc = sonuc);
    } catch (e) {
      if (mounted && istek == _istek) {
        setState(() {
          _sonuc = null;
          _hata = e is PosHatasi
              ? e.mesaj
              : 'Gün sonu yüklenemedi. Yeniden dene.';
        });
      }
    } finally {
      if (mounted && istek == _istek) setState(() => _yukleniyor = false);
    }
  }

  void _gunSec(Gun gun) {
    setState(() => _gun = gun);
    unawaited(_yukle());
  }

  Future<void> _aktar(GunSonu g) async {
    String? mesaj;
    try {
      // Tarayıcı indirmesini kendisi gösterir; vazgeçilince söylenecek bir şey yok.
      if (await widget.servis.disaAktar(g) == DosyaSonucu.kaydedildi) {
        mesaj = 'Gün sonu dosyası kaydedildi.';
      }
    } on PosHatasi catch (e) {
      mesaj = e.mesaj;
    } catch (_) {
      mesaj = 'Dosya kaydedilemedi. Yeniden dene.';
    }
    if (mesaj != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mesaj)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bugun = widget.servis.bugun;
    final kapandi = _gun.kapandi(widget.servis.saat());
    final g = _sonuc;
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        children: [
          SinirliIcerik(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Önceki gün',
                      onPressed: () => _gunSec(_gun.onceki),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      // Tarih ayrı okunur; altındaki kayıtlarla birleşmez.
                      child: Semantics(
                        container: true,
                        child: Column(
                          children: [
                            Text(
                              _gun == bugun ? 'Bugün' : _gun.etiket,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (_gun == bugun) Text(_gun.etiket),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sonraki gün',
                      onPressed: _gun.compareTo(bugun) >= 0
                          ? null
                          : () => _gunSec(_gun.sonraki),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GunDurumu(kapandi: kapandi),
                if (widget.yonetici) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Benim')),
                      ButtonSegment(value: true, label: Text('Herkes')),
                    ],
                    selected: {_herkes},
                    onSelectionChanged: (s) {
                      setState(() => _herkes = s.single);
                      unawaited(_yukle());
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_yukleniyor && g == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_hata != null) ...[
                  DurumNotu(_hata!, hata: true),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _yukleniyor ? null : _yukle,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Yeniden dene'),
                  ),
                ],
                if (g != null && g.gun == _gun) ..._icerik(g),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _icerik(GunSonu g) => [
    GunToplami(gunSonu: g),
    const SizedBox(height: 12),
    for (final c in g.sonucBekleyenler) ...[
      DurumNotu(
        widget.uygulamaIci
            ? '${c.cariAd}: son DenizPay girişinin sonucu kaydedilmedi. Ödeme '
                  'yapıldıysa cari profilinden “Ödeme sonucunu elle kaydet” '
                  'ile kaydet.'
            : '${c.cariAd}: son DenizPay girişinin sonucu kaydedilmedi. Ödeme '
                  'yapıldıysa sonuç ekranında “BUP Doldur”a dokun ya da cari '
                  'profilinden elle kaydet.',
        hata: true,
        simge: Icons.pending_actions_outlined,
      ),
      const SizedBox(height: 8),
    ],
    if (g.okunamayanAdet > 0) ...[
      DurumNotu(
        '${g.okunamayanAdet} başarılı işlemin tutarı okunamadı; toplama '
        'eklenmedi. DenizPay yazısı listede duruyor.',
        hata: true,
      ),
      const SizedBox(height: 8),
    ],
    if (g.bos)
      BosDurum(
        simge: Icons.receipt_long_outlined,
        baslik: 'Bu gün için kayıt yok',
        aciklama: widget.deneme
            ? 'Deneme kayıtları yalnız bugün görünür.'
            : 'DenizPay’e giriş ve ödeme sonuçları burada listelenir.',
      ),
    for (final c in g.cariler) ...[
      const SizedBox(height: 12),
      CariGunKarti(ozet: c, kullaniciGoster: _herkes),
    ],
    const SizedBox(height: 20),
    if (!g.bos && widget.servis.indirici.destekli)
      OutlinedButton.icon(
        onPressed: () => _aktar(g),
        icon: const Icon(Icons.download_rounded),
        label: const Text('Excel’e aktar (CSV)'),
      ),
    const SizedBox(height: 16),
    Semantics(
      container: true,
      child: const Text(
        'Kayıtlar sonradan değiştirilemez ve silinemez. Gün, Türkiye saatiyle '
        '00:00’da kendiliğinden kapanır.',
        style: TextStyle(fontSize: 13, color: PosRenk.ikincil),
      ),
    ),
  ];
}
