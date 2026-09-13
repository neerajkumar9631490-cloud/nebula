import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/runtime/app_target.dart';
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
          filter: ImageFilter.blur(
              sigmaX: AppTarget.glassBlur,
              sigmaY: AppTarget.glassBlur),
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
/// On TV it doubles as the D-pad focus target: press OK to activate and
/// a themed focus ring replaces the phone's tap-scale feedback.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius? focusBorderRadius;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.autofocus = false,
    this.focusNode,
    this.focusBorderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;
  FocusNode? _ownedNode;

  FocusNode get _node =>
      widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  void _activate() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Phone: the original tap-scale gesture. No focus machinery, so the
    // touch build stays exactly as it was.
    if (!AppTarget.isTv) {
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

    // TV: focusable + OK/Enter activation, with a visible focus ring.
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1.0,
        duration: AppTheme.fast,
        curve: AppTheme.curve,
        child: Stack(
          children: [
            widget.child,
            if (_focused)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.focusBorderRadius ??
                          BorderRadius.circular(AppTarget.focusRadius),
                      border: Border.all(
                          color: AppTarget.focusColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTarget.focusColor.withOpacity(0.35),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
