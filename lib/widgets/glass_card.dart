import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? margin, padding;
  final VoidCallback? onTap;
  const GlassCard(
      {super.key, required this.child, this.radius = 20, this.margin, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppTheme.stroke, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(scale: 0.98, onTap: onTap, child: card);
  }
}

/// Subtle press-down scale used across cards / buttons for a smooth feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppTheme.fast,
        curve: AppTheme.curve,
        child: widget.child,
      ),
    );
  }
}

/// Lightweight shimmer placeholder — no extra dependencies,
/// smooth looping gradient sweep.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, required this.width, required this.height, this.radius = 12});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _c.value * 2, -0.4),
              end: Alignment(0.2 + _c.value * 2, 0.4),
              colors: const [
                Color(0x1AFFFFFF),
                Color(0x30FFFFFF),
                Color(0x1AFFFFFF),
              ],
            ),
            border: Border.all(color: AppTheme.stroke),
          ),
        );
      },
    );
  }
}

/// Primary gradient CTA button with glow.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool expanded;
  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.onAccent, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.onAccent, fontWeight: FontWeight.w800, fontSize: 14.5)),
        ],
      ),
    );
    return Pressable(onTap: onTap, child: expanded ? SizedBox(width: double.infinity, child: btn) : btn);
  }
}
