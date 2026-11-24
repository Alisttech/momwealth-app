import 'package:flutter/material.dart';

/// Colours taken from the original MOMWEALTH design (#0F6E56 green).
class AppColors {
  static const green = Color(0xFF0F6E56);
  static const greenDark = Color(0xFF0B5643);
  static const greenLight = Color(0xFF14A06F);
  static const greenWash = Color(0xFFE9F2EF);
  static const gold = Color(0xFFB57A2E);
  static const goldWash = Color(0xFFFBF1E3);
  static const ink = Color(0xFF12241A);
  static const inkSoft = Color(0xFF5B6B60);
  static const line = Color(0xFFE4E7EB);
  static const bg = Color(0xFFF5F7F6);
  static const red = Color(0xFFC62828);
  static const redWash = Color(0xFFFBEAE7);
  static const blue = Color(0xFF2E5CB2);
  static const blueWash = Color(0xFFEAF0FB);
  static const purple = Color(0xFF6B4BB0);
  static const purpleWash = Color(0xFFF1ECFA);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'DMSans',
    fontFamilyFallback: const ['NairaFallback'], // DM Sans has no ₦
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green, primary: AppColors.green, surface: Colors.white),
    scaffoldBackgroundColor: AppColors.bg,
  );
  OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'DMSans', fontFamilyFallback: ['NairaFallback'], fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.green),
      errorBorder: border(AppColors.red),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontFamilyFallback: ['NairaFallback'], fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontFamilyFallback: ['NairaFallback'], fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.green, textStyle: const TextStyle(fontFamily: 'DMSans', fontFamilyFallback: ['NairaFallback'], fontWeight: FontWeight.w600)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.ink),
  );
}
