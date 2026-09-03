import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'badges.dart';

class PosterCard extends StatelessWidget {
  final MediaItem item;
  final String apiKey;
  final double? progress;
  final int? rank;

  const PosterCard({super.key, required this.item, required this.apiKey, this.progress, this.rank});

  @override
  Widget build(BuildContext context) {
    final imgUrl = TMDBService(apiKey).getImgUrl(item.posterPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.stroke, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (c, u, e) =>
                            const Center(child: Icon(Icons.movie_outlined, size: 42, color: AppTheme.textDim)),
                      )
                    : const Center(child: Icon(Icons.movie_outlined, size: 42, color: AppTheme.textDim)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent, Color(0xCC000000)],
                      stops: [0, 0.25, 1],
                    ),
                  ),
                ),
                if (rank != null) Positioned(left: 8, top: 8, child: RankBadge(rank: rank!)),
                Positioned(
                  right: 8,
                  top: 8,
                  child: TypeBadge(label: item.mediaType == 'tv' ? 'TV' : 'MOVIE'),
                ),
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: const Color(0x55FFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warn),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.text)),
        const SizedBox(height: 2),
        Row(
          children: [
            if (item.rating > 0) ...[
              const Icon(Icons.star_rounded, size: 13, color: AppTheme.star),
              const SizedBox(width: 3),
              Text(item.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: AppTheme.star, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
            ),
          ],
        ),
      ],
    );
  }
}
