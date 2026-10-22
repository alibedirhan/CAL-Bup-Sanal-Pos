import 'package:flutter/material.dart';
import '../domain/hata.dart';
import '../domain/modeller.dart';
import 'ortak.dart';
import 'oturum_modeli.dart';
import 'tema.dart';
import 'package:url_launcher/link.dart';

Future<void> posOnayiniAc(BuildContext context, OturumModeli model) =>
    altPencereAc<void>(context, (_) => PosOnayi(model: model));

class PosOnayi extends StatefulWidget {
  const PosOnayi({super.key, required this.model});
  final OturumModeli model;
  @override
  State<PosOnayi> createState() => _PosOnayiState();
}

class _PosOnayiState extends State<PosOnayi> {
  bool _onay = false, _mesgul = false, _girisAcildi = false;
  DenemeSonucu? _sonuc;
  String? _hata, _kayitHatasi;
  bool get _tamam => _sonuc != null;
  Future<void> _dene() async {
    if (!_onay || _mesgul) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final sonuc = await widget.model.dene();
    if (!mounted) return;
    setState(() {
      _mesgul = false;
      _sonuc = sonuc;
      _hata = sonuc == null
          ? widget.model.hata ?? 'Seçimi yenileyip tekrar deneyin.'
          : null;
    });
  }

  // Açılır pencere izni için tıklamayla eşzamanlı çalışır; yanıt okunmaz.
  void _girisYap() {
    try {
      final kayit = widget.model.posGirisiniAc(_sonuc!);
      setState(() {
        _girisAcildi = true;
        _hata = null;
        _kayitHatasi = null;
      });
      // Giriş kaydı gün sonundaki "sonuç bekleyen" uyarısı içindir; yazılamazsa
      // ödeme sonucu yine kaydedilebilir, kişi yalnız bilgilendirilir.
      kayit?.catchError((Object _) {
        if (mounted) {
          setState(
            () => _kayitHatasi =
                'Giriş kaydı sunucuya yazılamadı (bağlantı). Ödeme sonucunu yine kaydedebilirsin.',
          );
        }
      });
    } on PosHatasi catch (e) {
      setState(() => _hata = e.mesaj);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return SingleChildScrollView(
      child: SinirliIcerik(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tamam) ...[
              const Icon(Icons.task_alt, color: PosRenk.vurgu, size: 52),
              const SizedBox(height: 18),
              Text(
                m.deneme ? 'Geçiş denemesi tamamlandı' : 'Ödeme sitesine geç',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                m.deneme
                    ? 'Cari ve kart seçimi doğrulandı. Gerçek POS açılmadı; ödeme veya SMS işlemi yapılmadı.'
                    : m.otomatikGiris && _sonuc?.kart != null
                    ? 'DenizPay yeni sekmede bu carinin VKN / TC ve POS şifresiyle açılır. Kart sayfasında “BUP Doldur” yer imine dokun; kart numarası, ad ve son kullanma yazılır. CVV ve tutarı sen gir. Burada ödeme yapılmadı.'
                    : m.otomatikGiris
                    ? 'DenizPay yeni sekmede bu carinin VKN / TC ve POS şifresiyle açılır. Kart bilgileri, CVV ve tutarı ödeme sayfasında gir. Burada ödeme yapılmadı.'
                    : 'DenizPay giriş ekranı yeni sekmede açılır. Giriş, kart bilgileri, CVV ve tutarı ödeme sitesinde girmen gerekir. Seçili kart otomatik aktarılmaz; burada ödeme yapılmadı.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (m.otomatikGiris) ...[
                DurumNotu(
                  !_girisAcildi
                      ? 'Başka bir cariyle açık DenizPay sekmesi varsa önce onu kapat.'
                      : m.servis.tahsilat != null
                      ? 'DenizPay yeni sekmede açıldı. Ödeme bitince sonuç ekranında (Onay Formu / Hata Formu) “BUP Doldur”a dokun; sonuç bu cariye kaydedilir.'
                      : 'DenizPay yeni sekmede açıldı. Giriş olmadıysa aşağıdaki boş giriş sayfasından bilgileri elle gir.',
                ),
                const SizedBox(height: 12),
                if (_kayitHatasi != null) ...[
                  DurumNotu(_kayitHatasi!, hata: true),
                  const SizedBox(height: 12),
                ],
                if (_hata != null) ...[
                  DurumNotu(_hata!, hata: true),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _girisYap,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('DenizPay’e giriş yap'),
                ),
                const SizedBox(height: 12),
              ],
              if (!m.deneme) ...[
                Link(
                  uri: Uri.parse('https://denizpay.bupilic.com.tr/login.aspx'),
                  target: LinkTarget.blank,
                  builder: (context, ac) => m.otomatikGiris
                      ? OutlinedButton.icon(
                          // Elle girişte cari farklı olabilir: sonuç önceki
                          // cariye bağlanmasın diye son giriş işareti silinir.
                          onPressed: ac == null
                              ? null
                              : () {
                                  m.acikGirisiTemizle();
                                  ac();
                                },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Boş giriş sayfasını aç'),
                        )
                      : FilledButton.icon(
                          onPressed: ac,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('DenizPay ödeme girişini aç'),
                        ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kartlara dön'),
              ),
            ] else ...[
              Text(
                'Seçimini kontrol et',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 22),
              _Satir('Cari', m.profil?.cari.ad ?? 'Seçim yok'),
              const SizedBox(height: 16),
              _Satir(
                'Kart',
                m.seciliKart == null
                    ? 'Seçilmedi · kart bilgilerini ödeme sayfasında yazarsın'
                    : '${m.seciliKart!.ad} · ${m.seciliKart!.maske}',
              ),
              const SizedBox(height: 22),
              DurumNotu(
                m.deneme
                    ? 'Bu adım yalnızca geçiş denemesidir. Gerçek POS bağlantısı sağlayıcı doğrulamasından sonra açılacak.'
                    : m.otomatikGiris
                    ? 'Güncel cari ve kart özeti kontrol edilir. Tam kart bilgisi ödeme sitesine gönderilmez. Giriş bilgileri yalnız sonraki adımda “DenizPay’e giriş yap”a bastığında DenizPay’e gider.'
                    : 'Güncel cari ve kart özeti kontrol edilir. Tam kart bilgisi veya giriş şifresi bu uygulamadan ödeme sitesine gönderilmez.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _onay,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Cari ve seçili kartı kontrol ettim.'),
                onChanged: _mesgul
                    ? null
                    : (v) => setState(() => _onay = v ?? false),
              ),
              if (_hata != null) ...[
                DurumNotu(_hata!, hata: true),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _onay && !_mesgul ? _dene : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _mesgul
                      ? 'Kontrol ediliyor…'
                      : m.deneme
                      ? 'Geçişi dene'
                      : 'Seçimi kontrol et',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _mesgul ? null : () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.baslik, this.deger);
  final String baslik, deger;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(baslik),
      const SizedBox(height: 4),
      Text(deger, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
