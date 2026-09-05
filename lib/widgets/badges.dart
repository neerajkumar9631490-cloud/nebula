import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RankBadge extends StatelessWidget {
  final int rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = rank <= AppTheme.rankColors.length
        ? AppTheme.rankColors[rank - 1]
        : const Color(0x99000000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Text('#$rank',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
    );
  }
}

class TypeBadge extends StatelessWidget {
  final String label;
  const TypeBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.6)),
    );
  }
}

class RatingBadge extends StatelessWidget {
  final double rating;
  const RatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppTheme.star),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ],
      ),
    );
  }
}
