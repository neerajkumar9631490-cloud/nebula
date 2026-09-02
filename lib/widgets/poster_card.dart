import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';

class PosterCard extends StatelessWidget {
  final MediaItem item;
  final String apiKey;
  final double? progress;

  const PosterCard({super.key, required this.item, required this.apiKey, this.progress});

  @override
  Widget build(BuildContext context) {
    final imgUrl = TMDBService(apiKey).getImgUrl(item.posterPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.glassGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.stroke, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (c, u, e) => const Center(child: Icon(Icons.movie_outlined, size: 42, color: AppTheme.textDim)),
                            )
                          : const Center(child: Icon(Icons.movie_outlined, size: 42, color: AppTheme.textDim)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC06130C)],
                          ),
                        ),
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
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.text, height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${item.releaseYear} • ${item.mediaType.toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppTheme.textDim),
        ),
      ],
    );
  }
}
