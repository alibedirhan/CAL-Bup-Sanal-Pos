import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('İş kuralları Flutter, veri katmanı ve ekranlardan bağımsızdır', () {
    for (final katman in ['domain', 'application']) {
      for (final dosya in Directory(
        'lib/$katman',
      ).listSync(recursive: true).whereType<File>()) {
        if (!dosya.path.endsWith('.dart')) continue;
        final icerik = dosya.readAsStringSync();
        expect(
          RegExp(
            r'''(?:import|export)\s+['"].*(?:package:flutter|/ui/|/data/|dart:html|dart:io|firebase)''',
          ).hasMatch(icerik),
          isFalse,
          reason: dosya.path,
        );
      }
    }
  });
  test('Ekranlar somut veri deposu oluşturmaz', () {
    for (final dosya in Directory('lib/ui').listSync().whereType<File>()) {
      expect(
        dosya.readAsStringSync().contains('../data/'),
        isFalse,
        reason: dosya.path,
      );
    }
  });
  test(
    'Platform kodu kendi klasöründe kalır, yalnız kendi bileşimince alınır',
    () {
      // Klasör → onu içe aktarabilecek tek bileşim dosyası ve yasak içe aktarmalar.
      const platformlar = {
        'web': (
          bilesim: 'lib/bilesim/platform_web.dart',
          yasak: ['dart:io', 'package:flutter/services.dart'],
        ),
        'android': (
          bilesim: 'lib/bilesim/platform_android.dart',
          yasak: ['dart:js_interop', 'package:web/'],
        ),
      };
      final iceAktarma = RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"]''');
      for (final dosya in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!dosya.path.endsWith('.dart')) continue;
        final yol = dosya.path.replaceAll(r'\', '/');
        final hedefler = [
          for (final satir in dosya.readAsLinesSync())
            ?iceAktarma.firstMatch(satir.trim())?.group(1),
        ];
        final kendi = platformlar.keys
            .where((p) => yol.startsWith('lib/data/$p/'))
            .firstOrNull;
        for (final hedef in hedefler) {
          if (hedef == 'dart:js_interop' || hedef.startsWith('package:web/')) {
            expect(kendi, 'web', reason: '$yol → $hedef');
          }
          for (final MapEntry(key: p, value: k) in platformlar.entries) {
            if (hedef.contains('data/$p/') && kendi != p) {
              expect(yol, k.bilesim, reason: '$yol → $hedef');
            }
            if (kendi == p) {
              expect(
                k.yasak.any(hedef.startsWith),
                isFalse,
                reason: '$yol → $hedef',
              );
            }
          }
        }
      }
    },
  );
  test('El yazımı Dart dosyaları 400 satır sınırındadır', () {
    for (final dosya in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (dosya.path.endsWith('.dart')) {
        expect(
          dosya.readAsLinesSync().length,
          lessThanOrEqualTo(400),
          reason: dosya.path,
        );
      }
    }
  });
}
