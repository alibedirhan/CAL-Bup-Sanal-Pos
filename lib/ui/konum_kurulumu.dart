import 'package:flutter/material.dart';
import '../application/hesap_portu.dart';
import '../application/rota_kurulumu.dart';
import '../domain/hata.dart';
import '../domain/rota_kurulumu.dart';
import 'ortak.dart';
import 'tema.dart';

/// Yöneticinin terminalde bir kez yaptığı konum kurulumu (docs/ROTA_MIMARI.md
/// M16). Şifre yeniden sorulmadan açılmaz; terminaller yönetici hesabıyla açık
/// durduğu için (K19) bu kapı plasiyerin kurulumu değiştirmesini önler. Ekranda
/// konum verisi yoktur; onay ve takip yalnız CAL_bup'ta yönetilir.
Future<void> konumKurulumunuAc(
  BuildContext context,
  HesapPortu hesap,
  RotaKurulumPortu kurulum,
) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (_) => _SifrePenceresi(hesap: hesap),
  );
  if (onay != true || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => KonumKurulumuSayfasi(kurulum: kurulum),
    ),
  );
}

class _SifrePenceresi extends StatefulWidget {
  const _SifrePenceresi({required this.hesap});
  final HesapPortu hesap;
  @override
  State<_SifrePenceresi> createState() => _SifrePenceresiState();
}

class _SifrePenceresiState extends State<_SifrePenceresi> {
  final _sifre = TextEditingController();
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _dogrula() async {
    if (_mesgul || _sifre.text.isEmpty) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await widget.hesap.yenidenDogrula(_sifre.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = e is PosHatasi ? e.mesaj : 'Şifre doğrulanamadı.';
          _mesgul = false;
        });
      }
    } finally {
      _sifre.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Yönetici kurulumu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Devam etmek için şifreni yeniden yaz.'),
        const SizedBox(height: 12),
        TextField(
          controller: _sifre,
          obscureText: true,
          autofocus: true,
          enabled: !_mesgul,
          decoration: InputDecoration(labelText: 'Şifre', errorText: _hata),
          onSubmitted: (_) => _dogrula(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _mesgul ? null : () => Navigator.pop(context, false),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: _mesgul ? null : _dogrula,
        child: const Text('Devam'),
      ),
    ],
  );
}

class KonumKurulumuSayfasi extends StatefulWidget {
  const KonumKurulumuSayfasi({super.key, required this.kurulum});
  final RotaKurulumPortu kurulum;
  @override
  State<KonumKurulumuSayfasi> createState() => _KonumKurulumuSayfasiState();
}

class _KonumKurulumuSayfasiState extends State<KonumKurulumuSayfasi>
    with WidgetsBindingObserver {
  RotaKurulumDurumu? _durum;
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _yenile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ayarlar sayfasından (pil, konum, izin) dönünce durum yeniden okunur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _yenile();
  }

  Future<void> _yenile() async {
    try {
      final d = await widget.kurulum.durum();
      if (mounted) {
        setState(() {
          _durum = d;
          _hata = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hata = 'Durum okunamadı.');
    }
  }

  Future<void> _yap(Future<Object?> Function() islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    try {
      await islem();
    } catch (_) {
      if (mounted) setState(() => _hata = 'İşlem yapılamadı.');
    } finally {
      if (mounted) setState(() => _mesgul = false);
      await _yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum, k = widget.kurulum;
    return Scaffold(
      appBar: AppBar(title: const Text('Konum kurulumu')),
      body: ListView(
        children: [
          SinirliIcerik(
            child: d == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_hata ?? 'Okunuyor…'),
                  )
                : !d.etkin
                ? const DurumNotu('Bu derlemede konum takibi kapalı.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KodKarti(kod: d.kod),
                      const SizedBox(height: 16),
                      _Adim(
                        'Konum izni',
                        d.konumIzni,
                        'İzin ver',
                        _mesgul ? null : () => _yap(k.konumIzni),
                      ),
                      _Adim(
                        'Konuma her zaman izin',
                        d.arkaPlanIzni,
                        'Her zaman izin ver',
                        _mesgul || !d.konumIzni
                            ? null
                            : () => _yap(k.arkaPlanIzni),
                      ),
                      _Adim(
                        'Pil kısıtlaması kaldırıldı',
                        d.pilMuaf,
                        'Kısıtlamayı kaldır',
                        _mesgul ? null : () => _yap(k.pilMuafiyeti),
                      ),
                      _Adim(
                        'Telefonun konumu açık',
                        d.konumAcik,
                        'Konumu aç',
                        _mesgul ? null : () => _yap(k.konumAyari),
                      ),
                      _Adim(
                        'Arka plan hizmeti çalışıyor',
                        d.hizmet,
                        'Başlat',
                        _mesgul || !d.konumIzni ? null : () => _yap(k.baslat),
                      ),
                      const Divider(height: 32),
                      _Bilgi(
                        'Merkez onayı',
                        d.onayli
                            ? (d.takip
                                  ? 'Onaylı, takip açık'
                                  : 'Onaylı, takip kapalı')
                            : 'Bekliyor — CAL_bup Rota sekmesinde bu kodu onayla',
                      ),
                      _Bilgi('Gönderilmeyi bekleyen kayıt', '${d.bekleyen}'),
                      if (_hata != null) ...[
                        const SizedBox(height: 12),
                        Text(_hata!, style: TextStyle(color: PosRenk.hata)),
                      ],
                      const SizedBox(height: 16),
                      DurumNotu(
                        d.terminalHazir
                            ? 'Terminal hazır. Plasiyer bu ekranı görmez; terminalde konumla ilgili başka bir şey görünmez.'
                            : 'Eksik adımları tamamla. Her adım telefonun kendi ayar penceresini açar; dönünce bu liste yenilenir.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _mesgul ? null : _yenile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yenile'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _KodKarti extends StatelessWidget {
  const _KodKarti({required this.kod});
  final String? kod;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Terminal kodu'),
          const SizedBox(height: 8),
          SelectableText(
            kod ?? '— — —',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(letterSpacing: 6),
          ),
          const SizedBox(height: 8),
          Text(
            kod == null
                ? 'Kod, hizmet ilk kez internete bağlanınca oluşur.'
                : 'CAL_bup Rota sekmesinde bu kodu onayla ve aracı seç.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Adim extends StatelessWidget {
  const _Adim(this.ad, this.tamam, this.dugme, this.bas);
  final String ad, dugme;
  final bool tamam;
  final VoidCallback? bas;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          tamam ? Icons.check_circle : Icons.radio_button_unchecked,
          color: tamam ? PosRenk.vurgu : null,
          semanticLabel: tamam ? 'Tamam' : 'Eksik',
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(ad)),
        if (!tamam) TextButton(onPressed: bas, child: Text(dugme)),
      ],
    ),
  );
}

class _Bilgi extends StatelessWidget {
  const _Bilgi(this.ad, this.deger);
  final String ad, deger;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(ad)),
        const SizedBox(width: 12),
        Flexible(child: Text(deger, textAlign: TextAlign.end)),
      ],
    ),
  );
}
