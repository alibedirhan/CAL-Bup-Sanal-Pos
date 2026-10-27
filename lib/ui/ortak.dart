import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'tema.dart';

/// Android uygulaması mı (web sürümü değil). Yalnız metinlerin kullanıcının
/// diliyle söylenmesi için: "bu telefonda" / "bu tarayıcıda".
bool get androidUygulamasi =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String get kartSaklamaNotu => androidUygulamasi
    ? 'Tam kart bilgileri yalnız bu telefonda şifreli tutulur. Uygulama kaldırılırsa veya verileri silinirse yeniden eklemen gerekir. CVV ödeme ekranında girilir.'
    : 'Tam kart bilgileri yalnız bu tarayıcıda şifreli tutulur. Tarayıcı verileri silinirse yeniden eklemen gerekir. CVV ödeme ekranında girilir.';

/// Alttan açılan pencere. Üstte boşluk bırakılır: küçük ekranda (iPhone SE)
/// tutma çizgisi ekranın tepesine yapışmaz, aşağı çekerek kapatılabilir.
/// Klavye açılınca yükseklik görünen alana göre yeniden hesaplanır.
Future<T?> altPencereAc<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final klavye = mq.viewInsets.bottom;
        final yukseklik = (mq.size.height - klavye) * 0.88 + klavye;
        return ConstrainedBox(
          // Tutma çizgisi alanı içerikten ayrı yer kaplar.
          constraints: BoxConstraints(
            maxHeight: math.max(0, yukseklik - kMinInteractiveDimension),
          ),
          child: builder(context),
        );
      },
    );

class SinirliIcerik extends StatelessWidget {
  const SinirliIcerik({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class DurumNotu extends StatelessWidget {
  const DurumNotu(
    this.metin, {
    super.key,
    this.hata = false,
    this.simge = Icons.info_outline,
  });
  final String metin;
  final bool hata;
  final IconData simge;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: hata,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hata ? PosRenk.acikUyari : PosRenk.acikVurgu,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(simge, size: 20, color: hata ? PosRenk.uyari : PosRenk.vurgu),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: hata ? PosRenk.uyari : PosRenk.koyu,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CariAvatar extends StatelessWidget {
  const CariAvatar(this.ad, {super.key, this.buyuk = false});
  final String ad;
  final bool buyuk;
  @override
  Widget build(BuildContext context) {
    final parcalar = ad
        .replaceFirst('Örnek ', '')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2);
    final harfler = parcalar
        .map((s) => s.characters.first.toUpperCase())
        .join();
    return ExcludeSemantics(
      child: Container(
        width: buyuk ? 64 : 48,
        height: buyuk ? 64 : 48,
        decoration: BoxDecoration(
          color: PosRenk.acikVurgu,
          borderRadius: BorderRadius.circular(buyuk ? 20 : 15),
        ),
        alignment: Alignment.center,
        child: Text(
          harfler,
          style: TextStyle(
            fontSize: buyuk ? 23 : 16,
            fontWeight: FontWeight.w700,
            color: PosRenk.vurgu,
          ),
        ),
      ),
    );
  }
}

class BosDurum extends StatelessWidget {
  const BosDurum({
    super.key,
    required this.baslik,
    required this.aciklama,
    this.simge = Icons.search_rounded,
    this.eylem,
  });
  final String baslik, aciklama;
  final IconData simge;
  final Widget? eylem;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(simge, size: 42, color: PosRenk.ikincil),
        const SizedBox(height: 16),
        Text(
          baslik,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(aciklama, textAlign: TextAlign.center),
        if (eylem != null) ...[const SizedBox(height: 20), eylem!],
      ],
    ),
  );
}
