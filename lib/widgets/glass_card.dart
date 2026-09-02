import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? margin, padding;
  const GlassCard({super.key, required this.child, this.radius = 20, this.margin, this.padding});
  @override
  Widget build(BuildContext context) => Container(margin: margin, child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: Container(padding: padding, decoration: BoxDecoration(gradient: AppTheme.glassGradient, borderRadius: BorderRadius.circular(radius), border: Border.all(color: AppTheme.stroke, width: 1)), child: child)))));
}
