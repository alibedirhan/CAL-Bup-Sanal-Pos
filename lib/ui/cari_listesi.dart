import 'package:flutter/material.dart';
import '../domain/modeller.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';
import 'tema.dart';

class CariListesi extends StatefulWidget {
  const CariListesi({super.key, required this.model, required this.yeniCari});
  final OturumModeli model;
  final VoidCallback yeniCari;
  @override
  State<CariListesi> createState() => _CariListesiState();
}

class _CariListesiState extends State<CariListesi> {
  late final _arama = TextEditingController(text: widget.model.arama);
  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final cariler = m.gorunen;
    return CustomScrollView(
      key: const PageStorageKey('cariler'),
      slivers: [
        SliverToBoxAdapter(
          child: SinirliIcerik(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cariyi bul,\nkartını seç.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                const Text('Sanal POS işlemlerine tek yerden hazırlan.'),
                const SizedBox(height: 22),
                _Ozet(cariSayisi: m.cariler.length, kartSayisi: m.kartSayisi),
                const SizedBox(height: 22),
                TextField(
                  controller: _arama,
                  onChanged: m.ara,
                  maxLength: 80,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Cari adı veya VKN / TC ara',
                    counterText: '',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: m.arama.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            onPressed: () {
                              _arama.clear();
                              m.ara('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in CariFiltresi.values)
                      ChoiceChip(
                        selected: m.filtre == f,
                        label: Text(switch (f) {
                          CariFiltresi.tumu => 'Tümü',
                          CariFiltresi.yildizli => 'Yıldızlılar',
                          CariFiltresi.kartli => 'Kartı olanlar',
                        }),
                        onSelected: (_) => m.suz(f),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cariler · ${cariler.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: m.mesgul ? null : widget.yeniCari,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Yeni cari'),
                    ),
                    if (!m.deneme)
                      IconButton(
                        onPressed: m.mesgul ? null : m.yukle,
                        tooltip: 'Carileri yenile',
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
                if (m.hata != null) ...[
                  DurumNotu(m.hata!, hata: true),
                  TextButton(
                    onPressed: m.mesgul ? null : m.yukle,
                    child: const Text('Yeniden dene'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (m.mesgul && !m.hazir)
          const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (m.hazir && cariler.isEmpty)
          SliverToBoxAdapter(
            child: SinirliIcerik(
              child: BosDurum(
                baslik: m.cariler.isEmpty
                    ? 'İlk carini ekle'
                    : 'Cari bulunamadı',
                aciklama: m.cariler.isEmpty
                    ? 'Yeni cari düğmesiyle bir deneme kaydı oluşturabilirsin.'
                    : 'Farklı bir ad veya kimlik numarası deneyebilirsin.',
                eylem: m.cariler.isEmpty
                    ? FilledButton(
                        onPressed: widget.yeniCari,
                        child: const Text('Cari ekle'),
                      )
                    : null,
              ),
            ),
          ),
        SliverList.builder(
          itemCount: cariler.length,
          itemBuilder: (context, i) => SinirliIcerik(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _CariSatiri(
              ozet: cariler[i],
              onTap: m.mesgul ? null : () => m.profilAc(cariler[i].cari.id),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SinirliIcerik(
            child: DurumNotu(
              m.deneme
                  ? 'Deneme alanı · Kayıtlar örnektir ve bu oturumda kalır. Gerçek ödeme yapılmaz.'
                  : 'Kayıtlar hesabında saklanır. Burada ödeme alınmaz; işlem resmi ödeme sitesinde tamamlanır.',
              simge: Icons.science_outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.cariSayisi, required this.kartSayisi});
  final int cariSayisi, kartSayisi;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: PosRenk.koyu,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(22),
    child: Row(
      children: [
        Expanded(child: _Deger('$cariSayisi', 'Cari')),
        const SizedBox(width: 20),
        Expanded(child: _Deger('$kartSayisi', 'Kart özeti')),
        const ExcludeSemantics(
          child: Icon(
            Icons.credit_card_rounded,
            color: Color(0xFF83C6B7),
            size: 40,
          ),
        ),
      ],
    ),
  );
}

class _Deger extends StatelessWidget {
  const _Deger(this.deger, this.baslik);
  final String deger, baslik;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        deger,
        style: const TextStyle(
          color: PosRenk.beyaz,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        baslik,
        style: const TextStyle(color: Color(0xFFC4D9DD), fontSize: 13),
      ),
    ],
  );
}

class _CariSatiri extends StatelessWidget {
  const _CariSatiri({required this.ozet, this.onTap});
  final CariOzeti ozet;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: PosRenk.beyaz,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: PosRenk.cizgi),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CariAvatar(ozet.cari.ad),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ozet.cari.ad,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${ozet.cari.kimlikNo.isEmpty ? 'VKN / TC eklenmemiş' : ozet.cari.kimlikNo}  ·  ${ozet.kartSayisi == 0 ? 'Kart eklenmemiş' : '${ozet.kartSayisi} kart'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: PosRenk.ikincil,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (ozet.cari.yildizli)
              const Icon(Icons.star_rounded, size: 18, color: PosRenk.uyari),
            const Icon(Icons.chevron_right, color: PosRenk.ikincil),
          ],
        ),
      ),
    ),
  );
}
