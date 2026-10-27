import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../application/biyometrik_kilit.dart';
import '../../domain/biyometri.dart';
import 'kanal.dart';

/// Parmak izi/yüzle kilit açma (`BiyometriAnahtari.kt`). Bu telefonda tek kayıt
/// tutulur: son şifre doğrulayan hesap, an ve telefonun açılış sayacı. Kurallar
/// `domain/biyometri.dart`; anahtar her şifre doğrulamasında yenilenir, yeni
/// parmak izi/yüz eklenince Android tarafından geçersiz kılınır.
class AndroidBiyometrikKilit implements BiyometrikKilit {
  AndroidBiyometrikKilit({
    DateTime Function()? saat,
    Future<String> Function()? klasor,
  }) : _saat = saat ?? DateTime.now,
       _klasor = klasor ?? yedeksizKlasor;
  final DateTime Function() _saat;
  final Future<String> Function() _klasor;

  Future<File> get _dosya async => File('${await _klasor()}/biyometri.json');

  Future<({bool destekli, int acilis})> _durum() async {
    final d = await guvenlikKanali.invokeMapMethod<String, Object?>(
      'biyo.durum',
    );
    return (
      destekli: d?['destekli'] == true,
      acilis: d?['acilis'] is int ? d!['acilis'] as int : -1,
    );
  }

  Future<BiyometriKaydi?> _kayit() async {
    try {
      final f = await _dosya;
      if (!await f.exists()) return null;
      return BiyometriKaydi.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> kullanilabilir(String uid) async {
    try {
      final d = await _durum();
      final k = await _kayit();
      return d.destekli &&
          d.acilis >= 0 &&
          k != null &&
          k.gecerli(uid: uid, simdi: _saat(), acilis: d.acilis);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sifreDogrulandi(String uid) async {
    try {
      final onceki = await _kayit();
      if (onceki != null && onceki.uid != uid) await unut(onceki.uid);
      final d = await _durum();
      final etkin =
          d.destekli &&
          d.acilis >= 0 &&
          await guvenlikKanali.invokeMethod<bool>('biyo.etkinlestir', {
                'uid': uid,
              }) ==
              true;
      final f = await _dosya;
      if (!etkin) {
        if (await f.exists()) await f.delete();
        return;
      }
      final gecici = File('${f.path}.yeni');
      await gecici.writeAsString(
        jsonEncode(
          BiyometriKaydi(
            uid: uid,
            sonSifre: _saat(),
            acilis: d.acilis,
          ).toJson(),
        ),
        flush: true,
      );
      await gecici.rename(f.path);
    } catch (_) {
      // Biyometri etkinleşmezse kilit şifreyle açılmaya devam eder.
    }
  }

  @override
  Future<BiyometriSonucu> dogrula(String uid) async {
    if (!await kullanilabilir(uid)) return BiyometriSonucu.sifreGerekli;
    final String? r;
    try {
      r = await guvenlikKanali.invokeMethod<String>('biyo.dogrula', {
        'uid': uid,
        'baslik': 'BUP Sanal POS',
        'aciklama': 'Kilidi açmak için parmak izini veya yüzünü doğrula.',
      });
    } on PlatformException {
      return BiyometriSonucu.hata;
    }
    switch (r) {
      case 'tamam':
        return BiyometriSonucu.tamam;
      case 'iptal':
        return BiyometriSonucu.iptal;
      case 'gecersiz' || 'kilit':
        // Yeni biyometri eklendi ya da çok fazla hatalı deneme: hesap şifresi.
        await unut(uid);
        return BiyometriSonucu.sifreGerekli;
      default:
        return BiyometriSonucu.hata;
    }
  }

  @override
  Future<void> unut(String uid) async {
    try {
      await guvenlikKanali.invokeMethod<void>('biyo.sil', {'uid': uid});
    } catch (_) {
      // Anahtar kalsa da kayıt yoksa biyometriyle açılmaz.
    }
    try {
      final f = await _dosya;
      final k = await _kayit();
      if (await f.exists() && (k == null || k.uid == uid)) await f.delete();
    } catch (_) {}
  }
}
