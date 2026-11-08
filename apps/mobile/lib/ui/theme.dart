import 'package:flutter/material.dart';

/// Night-time palette used across the app.
abstract final class Palette {
  static const night = Color(0xFF0E1024);
  static const surface = Color(0xFF1A1D3A);
  static const surfaceHigh = Color(0xFF262A4F);
  static const moon = Color(0xFFF4C95D);
  static const blood = Color(0xFFE5484D);
  static const mist = Color(0xFFB8BCE0);
  static const day = Color(0xFFFFB86B);
  static const forest = Color(0xFF3DD68C);
  static const violet = Color(0xFF9B7BFF);

  static const avatarColors = [
    Color(0xFF7E57C2),
    Color(0xFF5C6BC0),
    Color(0xFF29B6F6),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  static const avatarIcons = ['🐺', '🦊', '🐻', '🦉', '🐱', '🐶', '🐰', '🦁', '🐸', '🐼', '🦝', '🐯', '🦇', '🐍', '🦄', '🐲', '👻', '🎃', '🌙', '⭐'];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.violet,
      brightness: Brightness.dark,
      primary: Palette.moon,
      onPrimary: Palette.night,
      secondary: Palette.violet,
      error: Palette.blood,
      surface: Palette.surface,
    ),
    scaffoldBackgroundColor: Palette.night,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Palette.night, centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      color: Palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
