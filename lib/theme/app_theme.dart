import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Palette extracted from reference image: charcoal + monochrome gray
  static const Color bg = Color(0xFF121212);
  static const Color surface = Color(0xFF191919);
  static const Color card = Color(0xFF1F1F1F);
  static const Color cardHi = Color(0xFF2A2A2A);
  static const Color stroke = Color(0xFF333333);
  static const Color text = Color(0xFFEDEDED);
  static const Color textDim = Color(0xFF9C9C9C);
  static const Color accent = Color(0xFFE6E6E6);
  static const Color onAccent = Color(0xFF121212);
  static const Color warn = Color(0xFFFF8A3D);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        onPrimary: onAccent,
        secondary: textDim,
        onSurface: text,
        onSurfaceVariant: textDim,
        outline: stroke,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: text,
        unselectedItemColor: textDim,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: textDim),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: textDim),
        prefixIconColor: textDim,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardHi,
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: stroke,
      popupMenuTheme: const PopupMenuThemeData(color: cardHi),
    );
  }
}
