import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'sources_screen.dart';

class DetailScreen extends StatelessWidget {
  final MediaItem item;
  final String apiKey;

  const DetailScreen({super.key, required this.item, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final service = TMDBService(apiKey);
    return Scaffold(
      appBar: AppBar(title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                height: 300,
                child: item.posterPath != null
                    ? CachedNetworkImage(imageUrl: service.getImgUrl(item.posterPath))
                    : const Icon(Icons.movie, size: 100),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(item.overview.isEmpty ? 'No overview available.' : item.overview),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Find Sources'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SourcesScreen(item: item, apiKey: apiKey),
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
