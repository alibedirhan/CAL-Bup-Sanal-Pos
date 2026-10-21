import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/hata.dart';
import '../domain/kullanici.dart';
import '../domain/modeller.dart';

Kullanici kullaniciOku(String id, Map<String, dynamic>? d) {
  if (d == null) {
    throw const PosHatasi(
      'yetki',
      'Bu hesaba henüz erişim verilmemiş. Yöneticiyle görüşün.',
    );
  }
  return Kullanici(
    id: id,
    ad: d['ad'] as String,
    eposta: d['eposta'] as String,
    yonetici: d['yonetici'] == true,
    aktif: d['aktif'] == true,
  );
}

CariProfili cariOku(String id, Map<String, dynamic>? d) {
  if (d == null || d['silindi'] != false) {
    throw const PosHatasi(
      'cari_yok',
      'Cari bulunamadı veya erişiminiz kaldırıldı.',
    );
  }
  final cari = Cari(
    id: id,
    sahipId: d['sahipId'] as String,
    ad: d['ad'] as String,
    kod: d['kod'] as String,
    yildizli: d['yildizli'] as bool,
    surum: d['surum'] as int,
    kimlikNo: d['kimlikNo'] as String? ?? '',
  );
  final kartlar = (d['kartlar'] as List).map(
    (k) => KartOzeti(
      id: k['id'] as String,
      cariId: id,
      ad: k['ad'] as String,
      sonDort: k['sonDort'] as String,
      ay: k['ay'] as int,
      yil: k['yil'] as int,
      cihazKayitId: k['cihazKayitId'] as String?,
    ),
  );
  return CariProfili(cari, kartlar);
}

Map<String, dynamic> kartYaz(KartOzeti k) => {
  'id': k.id,
  'ad': k.ad,
  'sonDort': k.sonDort,
  'ay': k.ay,
  'yil': k.yil,
  if (k.cihazKayitId != null) 'cihazKayitId': k.cihazKayitId,
};

Map<String, dynamic> cariYaz(
  Cari c,
  List<KartOzeti> kartlar, {
  Object? olusturma,
  bool silindi = false,
  KartOzeti? sonKart,
}) => {
  'sahipId': c.sahipId,
  'ad': c.ad,
  'kod': c.kod,
  'kodAnahtari': c.kod.toUpperCase(),
  'yildizli': c.yildizli,
  'surum': c.surum,
  'kartlar': kartlar.map(kartYaz).toList(),
  'sonKart': sonKart == null ? null : kartYaz(sonKart),
  'kimlikNo': c.kimlikNo,
  'silindi': silindi,
  'olusturma': olusturma ?? FieldValue.serverTimestamp(),
  'guncelleme': FieldValue.serverTimestamp(),
};

PosHatasi bulutHatasi(Object e) {
  if (e is PosHatasi) return e;
  if (e is TimeoutException) {
    return const PosHatasi(
      'baglanti',
      'Sunucu yanıtı gecikti. Kayıt yapılmış olabilir; yeniden eklemeden önce listeyi yenileyip kontrol edin.',
    );
  }
  if (e is FirebaseException) {
    return switch (e.code) {
      'permission-denied' || 'unauthenticated' => const PosHatasi(
        'yetki',
        'Bu işlem için erişiminiz yok. Oturumu yenileyin veya yöneticiyle görüşün.',
      ),
      'unavailable' || 'deadline-exceeded' => const PosHatasi(
        'baglanti',
        'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip yeniden deneyin.',
      ),
      'aborted' => const PosHatasi(
        'surum',
        'Kayıt başka cihazda değişti. Yenileyip tekrar deneyin.',
      ),
      _ => const PosHatasi(
        'bulut',
        'Kayıt işlemi tamamlanamadı. Yenileyip tekrar deneyin.',
      ),
    };
  }
  return const PosHatasi('veri', 'Kayıt okunamadı. Yöneticiyle görüşün.');
}
