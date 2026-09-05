import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Movix professional design system.
/// Cinematic dark theme with soft glass surfaces, layered depth,
/// consistent radii, motion and typography.
class AppTheme {
  AppTheme._();

  // ── Palette ──────────────────────────────────────────────
  static const Color bg = Color(0xFF070B12);
  static const Color bgHi = Color(0xFF0C1220);
  static const Color surface = Color(0xFF101827);
  static const Color card = Color(0x14FFFFFF);
  static const Color cardHi = Color(0x22FFFFFF);
  static const Color stroke = Color(0x24FFFFFF);
  static const Color strokeHi = Color(0x3DFFFFFF);
  static const Color text = Color(0xFFF4F7FB);
  static const Color textDim = Color(0xFF9AA9BD);
  static const Color textFaint = Color(0xFF6B7A90);
  static const Color accent = Color(0xFF2FD97C);
  static const Color accentHi = Color(0xFF5CEFA0);
  static const Color accentDeep = Color(0xFF0E7A42);
  static const Color onAccent = Color(0xFF04240F);
  static const Color warn = Color(0xFFFFB454);
  static const Color star = Color(0xFFFFC648);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF39A7FF);

  static const List<Color> rankColors = [
    Color(0xFFE91E63),
    Color(0xFFFF7A2F),
    Color(0xFFFFB454),
    Color(0xFF2FD97C),
    Color(0xFF39A7FF),
  ];

  // ── Gradients ────────────────────────────────────────────
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2BFFFFFF), Color(0x0DFFFFFF)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHi, accent, accentDeep],
  );

  static const LinearGradient heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x0D070B12),
      Color(0x99070B12),
      Color(0xFF070B12),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient cardScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x55000000), Colors.transparent, Color(0xD9000000)],
    stops: [0, 0.3, 1],
  );

  // ── Radii / elevation / motion ───────────────────────────
  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 20;
  static const double rXl = 28;

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
      ];

  static List<BoxShadow> get glowShadow => const [
        BoxShadow(color: Color(0x552FD97C), blurRadius: 24, offset: Offset(0, 8)),
      ];

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration med = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;

  // ── Text ─────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    color: text, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    color: text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.2,
  );
  static const TextStyle subtitle = TextStyle(
    color: textDim, fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    color: textFaint, fontSize: 12, fontWeight: FontWeight.w500,
  );

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
        error: danger,
      ),
    );
    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        iconTheme: IconThemeData(color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF00C1220),
        indicatorColor: accent.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accent, size: 24);
          }
          return const IconThemeData(color: textDim, size: 23);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xF00C1220),
        selectedItemColor: accent,
        unselectedItemColor: textDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
          side: const BorderSide(color: stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
          side: const BorderSide(color: stroke),
        ),
        titleTextStyle: const TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(color: textDim, fontSize: 14, height: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgHi,
        modalBackgroundColor: bgHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.black.withOpacity(0.06)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: strokeHi),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          backgroundColor: const Color(0x1AFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        hintStyle: const TextStyle(color: textFaint, fontSize: 14),
        labelStyle: const TextStyle(color: textDim, fontSize: 13),
        prefixIconColor: textDim,
        suffixIconColor: textDim,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rMd), borderSide: const BorderSide(color: stroke)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rMd), borderSide: const BorderSide(color: stroke)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rMd),
            borderSide: const BorderSide(color: accent, width: 1.4)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rMd),
            borderSide: const BorderSide(color: danger)),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(const Color(0x1AFFFFFF)),
        elevation: WidgetStateProperty.all(0),
        side: WidgetStateProperty.all(const BorderSide(color: stroke)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        hintStyle: WidgetStateProperty.all(const TextStyle(color: textFaint, fontSize: 14)),
        textStyle: WidgetStateProperty.all(const TextStyle(color: text, fontSize: 14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x1AFFFFFF),
        selectedColor: accent.withOpacity(0.18),
        labelStyle: const TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: textDim, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: const BorderSide(color: stroke)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Color(0x26FFFFFF),
        circularTrackColor: Color(0x26FFFFFF),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: const Color(0x33FFFFFF),
        thumbColor: Colors.white,
        overlayColor: accent.withOpacity(0.15),
        trackHeight: 3,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textDim,
        textColor: text,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dividerColor: stroke,
      dividerTheme: const DividerThemeData(color: stroke, thickness: 1, space: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 10,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd), side: const BorderSide(color: stroke)),
        textStyle: const TextStyle(color: text),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: text, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: stroke)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: stroke),
        ),
        textStyle: const TextStyle(color: text, fontSize: 12),
      ),
    );
  }
}
