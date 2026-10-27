import 'dart:async';
import 'package:flutter/material.dart';
import '../application/denizpay_oturumu.dart';
import '../domain/kart_bilgileri.dart';
import '../domain/tahsilat.dart';
import 'ortak.dart';
import 'tema.dart';

/// Uygulama içi DenizPay ekranını açan bileşim işlevi (Android; web'de yok).
/// Platform bağdaştırıcısı [DenizPayOturumu] ve tarayıcı görünümünü kurar.
typedef DenizPayAcici =
    Future<void> Function(
      BuildContext context,
      DenizPayBaglami baglam,
      Future<KartBilgileri?> Function() kartiOku,
    );

/// Uygulama içi DenizPay (docs/ANDROID_PLANI.md §3). Üstte cari ve açık sitenin
/// adresi; altta yalnız gerektiğinde "Kartı doldur" veya sonuç kaydı. Ekran
/// kapanınca DenizPay oturumu silinir.
class DenizPayEkrani extends StatefulWidget {
  const DenizPayEkrani({
    super.key,
    required this.oturum,
    required this.gorunum,
  });
  final DenizPayOturumu oturum;
  final Widget gorunum;
  @override
  State<DenizPayEkrani> createState() => _DenizPayEkraniState();
}

class _DenizPayEkraniState extends State<DenizPayEkrani> {
  late final StreamSubscription<DenizPayDurumu> _abone;
  String? _acilisHatasi;

  DenizPayOturumu get _o => widget.oturum;

  @override
  void initState() {
    super.initState();
    _abone = _o.durumlar.listen((_) {
      if (mounted) setState(() {});
    });
    _o.baslat().catchError((Object _) {
      if (mounted) {
        setState(
          () => _acilisHatasi =
              'DenizPay açılamadı. İnternet bağlantını kontrol edip yeniden dene.',
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_abone.cancel());
    unawaited(_o.kapat());
    super.dispose();
  }

  /// Kaydedilmemiş sonuç ya da sürmekte olan ödeme varken kapatma onay ister.
  Future<bool> _kapatilsinMi() async {
    final d = _o.durum;
    final sonucBekliyor = d.sonuc != null && !d.birakildi;
    final odemeSuruyor =
        d.sayfa == DenizPaySayfasi.kart || d.sayfa == DenizPaySayfasi.disSite;
    if (!sonucBekliyor && !odemeSuruyor) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('DenizPay kapatılsın mı?'),
            content: Text(
              sonucBekliyor
                  ? 'Sonucu henüz bu cariye kaydetmedin. Kapatırsan cari profilinden elle kaydetmen gerekir.'
                  : 'Ödeme sürüyorsa yarıda kalır. DenizPay oturumu bu telefondan silinir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _kapat() async {
    if (await _kapatilsinMi() && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = _o.durum;
    final k = _o.baglam.kayit;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (cikti, _) {
        if (!cikti) unawaited(_kapat());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'DenizPay’i kapat',
            onPressed: _kapat,
            icon: const Icon(Icons.close_rounded),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                k.cariAd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'VKN / TC ${k.kimlikNo}',
                style: const TextStyle(fontSize: 13, color: PosRenk.ikincil),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _AdresSeridi(durum: d, oturum: _o),
            if (d.sayfa == DenizPaySayfasi.yukleniyor || d.mesgul)
              const LinearProgressIndicator(minHeight: 2),
            if (_acilisHatasi != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: DurumNotu(_acilisHatasi!, hata: true),
              ),
            Expanded(child: widget.gorunum),
            _AltPanel(oturum: _o),
          ],
        ),
      ),
    );
  }
}

class _AdresSeridi extends StatelessWidget {
  const _AdresSeridi({required this.durum, required this.oturum});
  final DenizPayDurumu durum;
  final DenizPayOturumu oturum;
  @override
  Widget build(BuildContext context) {
    final u = durum.adres;
    final denizPay = u != null && oturum.adres.denizPayMi(u);
    final guvenli = u?.scheme == 'https';
    return Semantics(
      container: true,
      label: 'Açık sayfa',
      child: Container(
        width: double.infinity,
        color: PosRenk.acikVurgu,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              guvenli ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 16,
              color: guvenli ? PosRenk.vurgu : PosRenk.uyari,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                u == null
                    ? 'DenizPay açılıyor…'
                    : denizPay
                    ? u.host
                    : 'Banka sayfası: ${u.host}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: PosRenk.koyu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AltPanel extends StatelessWidget {
  const _AltPanel({required this.oturum});
  final DenizPayOturumu oturum;

  @override
  Widget build(BuildContext context) {
    final d = oturum.durum;
    final ogeler = <Widget>[
      if (d.sayfa == DenizPaySayfasi.kart) ..._kart(d),
      if (d.sayfa == DenizPaySayfasi.sonuc) ..._sonuc(context, d),
      if (d.not != null && d.sayfa != DenizPaySayfasi.kart)
        DurumNotu(d.not!, hata: d.notHata),
    ];
    if (ogeler.isEmpty) return const SizedBox.shrink();
    return Material(
      color: PosRenk.beyaz,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, o) in ogeler.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                o,
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _kart(DenizPayDurumu d) {
    final kart = oturum.baglam.kart;
    return [
      if (d.not != null)
        DurumNotu(d.not!, hata: d.notHata)
      else if (kart == null)
        const DurumNotu(
          'Kart seçmedin. Kart bilgilerini, CVV’yi ve tutarı bu sayfada kendin yaz.',
        )
      else if (kart.cihazKayitId == null)
        const DurumNotu(
          'Bu kartın tam bilgisi bu telefonda yok. Kart bilgilerini bu sayfada kendin yaz.',
        ),
      if (oturum.kartDoldurulabilir)
        FilledButton.icon(
          onPressed: oturum.kartiDoldur,
          icon: const Icon(Icons.credit_card_rounded),
          label: Text('Kartı doldur (•••• ${kart!.sonDort})'),
        ),
    ];
  }

  List<Widget> _sonuc(BuildContext context, DenizPayDurumu d) {
    final s = d.sonuc;
    if (s == null) {
      return [
        DurumNotu(
          d.sonucHatasi ??
              'Sonuç okunamadı. Cari profilinden “Ödeme sonucunu elle kaydet” ile kaydet.',
          hata: true,
        ),
      ];
    }
    final basarili = s.sonuc == IslemSonucu.basarili;
    final tutar = s.tutarKurus == null ? s.tutarMetni : tutarYaz(s.tutarKurus!);
    return [
      Semantics(
        container: true,
        child: Row(
          children: [
            Icon(
              basarili ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: basarili ? PosRenk.vurgu : PosRenk.hata,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${basarili ? 'Ödeme başarılı' : 'Ödeme başarısız'} · $tutar\n'
                'Pos No ${s.posSiparisNo}'
                '${basarili ? '' : ' · ${s.aciklama}'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      if (d.kayitNotu != null)
        DurumNotu(
          d.kayitNotu!,
          hata: d.kayitHata,
          simge: d.kayitTamam ? Icons.task_alt : Icons.info_outline,
        ),
      if (!d.birakildi)
        FilledButton.icon(
          onPressed: d.mesgul ? null : oturum.sonucuKaydet,
          icon: const Icon(Icons.save_rounded),
          label: Text('Bu cariye kaydet: ${oturum.baglam.kayit.cariAd}'),
        ),
    ];
  }
}
