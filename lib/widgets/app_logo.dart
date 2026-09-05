import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single source of truth for the Movix brand mark.
/// Used for splash, setup, app bars and settings — never for
/// play/action buttons (those keep their play icons).
class AppLogo extends StatelessWidget {
  final double size;
  final double radius;
  final bool glow;
  final bool border;

  const AppLogo({
    super.key,
    this.size = 48,
    this.radius = 14,
    this.glow = true,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius <= 0 ? size * 0.28 : radius;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: border
            ? Border.all(color: AppTheme.strokeHi, width: 1)
            : null,
        boxShadow: glow ? AppTheme.glowShadow : AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (c, e, s) => Container(
            color: AppTheme.accent,
            child: Icon(Icons.play_arrow_rounded,
                size: size * 0.55, color: AppTheme.onAccent),
          ),
        ),
      ),
    );
  }
}
