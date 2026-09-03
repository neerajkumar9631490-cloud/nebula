import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RankBadge extends StatelessWidget {
  final int rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = rank <= AppTheme.rankColors.length
        ? AppTheme.rankColors[rank - 1]
        : const Color(0x66000000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Text('$rank',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class TypeBadge extends StatelessWidget {
  final String label;
  const TypeBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(7)),
      child: Text(label,
          style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}
