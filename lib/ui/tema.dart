import 'package:flutter/material.dart';

abstract final class PosRenk {
  static const zemin = Color(0xFFF4F6F8);
  static const beyaz = Color(0xFFFFFFFF);
  static const koyu = Color(0xFF16343E);
  static const vurgu = Color(0xFF08786E);
  static const acikVurgu = Color(0xFFE6F3EF);
  static const metin = Color(0xFF172E36);
  static const ikincil = Color(0xFF526671);
  static const cizgi = Color(0xFFDCE4E7);
  static const uyari = Color(0xFF86520F);
  static const acikUyari = Color(0xFFFFF4DF);
  static const hata = Color(0xFFAA3038);
}

ThemeData posTemasi() {
  final temel = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: PosRenk.vurgu).copyWith(
      primary: PosRenk.vurgu,
      onPrimary: PosRenk.beyaz,
      surface: PosRenk.beyaz,
      onSurface: PosRenk.metin,
      error: PosRenk.hata,
    ),
  );
  return temel.copyWith(
    scaffoldBackgroundColor: PosRenk.zemin,
    textTheme: temel.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: PosRenk.metin,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: PosRenk.metin,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: PosRenk.metin,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: PosRenk.metin,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: PosRenk.metin,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: PosRenk.ikincil,
          ),
          labelLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: const AppBarTheme(
      backgroundColor: PosRenk.zemin,
      foregroundColor: PosRenk.metin,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 72,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: PosRenk.cizgi),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PosRenk.beyaz,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PosRenk.cizgi),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PosRenk.cizgi),
      ),
    ),
    chipTheme: temel.chipTheme.copyWith(
      side: const BorderSide(color: PosRenk.cizgi),
      backgroundColor: PosRenk.beyaz,
      selectedColor: PosRenk.acikVurgu,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PosRenk.beyaz,
      indicatorColor: PosRenk.acikVurgu,
      height: 76,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(
      color: PosRenk.cizgi,
      thickness: 1,
      space: 1,
    ),
  );
}
