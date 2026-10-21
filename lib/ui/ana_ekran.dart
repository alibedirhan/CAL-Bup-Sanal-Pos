import 'package:flutter/material.dart';
import 'bilgi_sayfasi.dart';
import 'cari_formu.dart';
import 'cari_listesi.dart';
import 'cari_profili.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';
import 'pos_onayi.dart';
import 'tema.dart';
import '../application/hesap_portu.dart';
import '../domain/kullanici.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({
    super.key,
    required this.model,
    required this.kilitle,
    this.kullanici,
    this.hesap,
    this.yonetim,
  });
  final OturumModeli model;
  final VoidCallback kilitle;
  final Kullanici? kullanici;
  final HesapPortu? hesap;
  final YonetimPortu? yonetim;
  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _sekme = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model;
      final detay = m.profil != null;
      return PopScope(
        canPop: !detay,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !m.mesgul) m.geri();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: detay
                ? IconButton(
                    tooltip: 'Carilere dön',
                    onPressed: m.mesgul ? null : m.geri,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!detay) ...[
                  const Icon(
                    Icons.credit_card_rounded,
                    color: PosRenk.vurgu,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    detay ? 'Cari profili' : 'Sanal POS',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text(
                    m.deneme ? 'Deneme' : '0.7.0',
                    style: const TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                tooltip: 'Ekranı kilitle',
                onPressed: widget.kilitle,
                icon: const Icon(Icons.lock_outline, size: 22),
              ),
              const SizedBox(width: 6),
            ],
            bottom: m.mesgul
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                if (m.uyari != null) SinirliIcerik(child: DurumNotu(m.uyari!)),
                Expanded(
                  child: detay
                      ? CariProfiliEkrani(model: m, yonetim: widget.yonetim)
                      : _sekme == 0
                      ? CariListesi(
                          model: m,
                          yeniCari: () => cariFormunuAc(context, m),
                        )
                      : BilgiSayfasi(
                          kilitle: widget.kilitle,
                          kullanici: widget.kullanici,
                          hesap: widget.hesap,
                          yonetim: widget.yonetim,
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: detay
              ? _IslemCubugu(model: m)
              : NavigationBar(
                  selectedIndex: _sekme,
                  onDestinationSelected: (v) => setState(() => _sekme = v),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people_rounded),
                      label: 'Cariler',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_rounded),
                      label: 'Çalışma alanı',
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

class _IslemCubugu extends StatelessWidget {
  const _IslemCubugu({required this.model});
  final OturumModeli model;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: PosRenk.beyaz,
      border: Border(top: BorderSide(color: PosRenk.cizgi)),
    ),
    child: SafeArea(
      top: false,
      child: SinirliIcerik(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                model.seciliKart != null
                    ? '${model.seciliKart!.ad} · ${model.seciliKart!.maske}'
                    : model.otomatikGiris
                    ? 'Kart seçmeden de DenizPay’e girebilirsin.'
                    : 'Devam etmek için bir kart seç.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: PosRenk.ikincil),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed:
                  (model.seciliKart == null && !model.otomatikGiris) ||
                      model.mesgul
                  ? null
                  : () => posOnayiniAc(context, model),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                model.deneme ? 'POS’a geçişi dene' : 'Ödeme sitesine geç',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
