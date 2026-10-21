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
