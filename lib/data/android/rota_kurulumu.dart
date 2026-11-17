import 'package:flutter/services.dart';
import '../../application/rota_kurulumu.dart';
import '../../domain/rota_kurulumu.dart';

/// Kotlin karşılığı `rota/RotaKanali.kt`.
class AndroidRotaKurulumu implements RotaKurulumPortu {
  const AndroidRotaKurulumu();
  static const _kanal = MethodChannel('bup/rota');

  @override
  Future<RotaKurulumDurumu> durum() async => RotaKurulumDurumu.haritadan(
    await _kanal.invokeMapMethod<Object?, Object?>('durum') ?? const {},
  );
  @override
  Future<bool> konumIzni() async =>
      await _kanal.invokeMethod<bool>('konumIzni') ?? false;
  @override
  Future<bool> arkaPlanIzni() async =>
      await _kanal.invokeMethod<bool>('arkaPlanIzni') ?? false;
  @override
  Future<void> pilMuafiyeti() => _kanal.invokeMethod<void>('pilMuafiyeti');
  @override
  Future<void> konumAyari() => _kanal.invokeMethod<void>('konumAyari');
  @override
  Future<bool> baslat() async =>
      await _kanal.invokeMethod<bool>('baslat') ?? false;
}
