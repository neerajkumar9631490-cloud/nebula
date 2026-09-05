import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAll;
  const SectionHeader({super.key, required this.title, this.subtitle, this.onAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textFaint)),
              ],
            ),
          ),
          if (onAll != null)
            TextButton(
              onPressed: onAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See all',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
