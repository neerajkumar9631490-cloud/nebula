import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();
  static const Color bg = Color(0xFF06130C);
  static const Color surface = Color(0xFF0B1F15);
  static const Color card = Color(0x14FFFFFF);
  static const Color cardHi = Color(0x24FFFFFF);
  static const Color stroke = Color(0x2EFFFFFF);
  static const Color text = Color(0xFFF1FBF5);
  static const Color textDim = Color(0xFF9DBBA8);
  static const Color accent = Color(0xFF2FD97C);
  static const Color onAccent = Color(0xFF04240F);
  static const Color warn = Color(0xFFFFB454);
  static const LinearGradient glassGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)]);

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(surface: surface, primary: accent, onPrimary: onAccent, secondary: textDim, onSurface: text, onSurfaceVariant: textDim, outline: stroke));
    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5), iconTheme: IconThemeData(color: text)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xE60B1F15), selectedItemColor: accent, unselectedItemColor: textDim, type: BottomNavigationBarType.fixed, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: onAccent, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent)),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: text)),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: card, hintStyle: const TextStyle(color: textDim), prefixIconColor: textDim, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.2))),
      snackBarTheme: const SnackBarThemeData(backgroundColor: cardHi, behavior: SnackBarBehavior.floating),
      dividerColor: stroke,
      popupMenuTheme: const PopupMenuThemeData(color: cardHi),
    );
  }
}
