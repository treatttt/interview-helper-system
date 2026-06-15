import 'package:flutter/material.dart';

// Цветовая палитра и тема приложения.
class AppColors {
  static const primary = Color(0xFF534AB7); // фиолетовый акцент
  static const success = Color(0xFF0F6E56);
  static const successBg = Color(0xFFE1F5EE);
  static const danger = Color(0xFFA32D2D);
  static const dangerBg = Color(0xFFFCEBEB);
  static const info = Color(0xFF185FA5);
  static const infoBg = Color(0xFFE6F1FB);
  static const warning = Color(0xFF854F0B);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F6F2);
  static const textPrimary = Color(0xFF1A1A18);
  static const textSecondary = Color(0xFF5F5E5A);
  static const border = Color(0xFFE4E2DA);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
