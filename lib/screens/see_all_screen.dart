import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';

/// Full-category grid behind every home "SEE ALL" button.
class SeeAllScreen extends StatelessWidget {
  final String title;
  final List<MediaItem> items;

  const SeeAllScreen({super.key, required this.title, required this.items});

  void _open(BuildContext context, MediaItem item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19)),
      ),
      body: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 32 + MediaQuery.of(context).padding.bottom),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 2 / 3,
        ),
        itemCount: items.length,
        itemBuilder: (c, i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 220 + (i % 9) * 35),
          curve: AppTheme.curve,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 16),
              child: child,
            ),
          ),
          child: Pressable(
            onTap: () => _open(context, items[i]),
            child: PosterTile(item: items[i], radius: 18),
          ),
        ),
      ),
    );
  }
}
