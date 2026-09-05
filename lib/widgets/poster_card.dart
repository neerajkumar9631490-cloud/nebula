import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'badges.dart';
import 'glass_card.dart';

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
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              border: Border.all(color: AppTheme.stroke, width: 1),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterPath != null)
                    CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      fadeInDuration: AppTheme.fast,
                      fadeOutDuration: AppTheme.fast,
                      placeholder: (c, u) => Container(
                        color: AppTheme.surface,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (c, u, e) => Container(
                        color: AppTheme.surface,
                        child: const Center(
                            child: Icon(Icons.movie_outlined,
                                size: 40, color: AppTheme.textFaint)),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surface,
                      child: const Center(
                          child: Icon(Icons.movie_outlined,
                              size: 40, color: AppTheme.textFaint)),
                    ),
                  const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.cardScrim)),
                  if (rank != null)
                    Positioned(left: 8, top: 8, child: RankBadge(rank: rank!)),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: TypeBadge(label: item.mediaType == 'tv' ? 'TV' : 'MOVIE'),
                  ),
                  if (item.rating > 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: RatingBadge(rating: item.rating),
                    ),
                  if (progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3.5,
                          backgroundColor: const Color(0x55FFFFFF),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text, height: 1.2)),
        const SizedBox(height: 3),
        Row(
          children: [
            if (item.rating > 0) ...[
              const Icon(Icons.star_rounded, size: 13, color: AppTheme.star),
              const SizedBox(width: 3),
              Text(item.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.star, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Text('•',
                  style: TextStyle(fontSize: 11, color: AppTheme.textFaint)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                  item.releaseYear.isEmpty
                      ? item.mediaType.toUpperCase()
                      : '${item.releaseYear}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textDim)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Skeleton shown while rows load — keeps layout stable and feels smooth.
class PosterRowSkeleton extends StatelessWidget {
  final int count;
  const PosterRowSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) => const SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 132, height: 186, radius: 14),
              SizedBox(height: 8),
              ShimmerBox(width: 110, height: 12, radius: 6),
              SizedBox(height: 6),
              ShimmerBox(width: 70, height: 10, radius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
