import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const SectionHeader({super.key, required this.title, this.onAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text)),
          const Spacer(),
          if (onAll != null)
            TextButton(
              onPressed: onAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textDim),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
