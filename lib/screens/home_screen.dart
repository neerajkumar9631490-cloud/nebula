import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'search_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final String apiKey;
  const HomeScreen({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final service = TMDBService(apiKey);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nebula'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(apiKey: apiKey))),
          )
        ],
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: service.getTrending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data found.'));
          }
          
          final items = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Trending This Week', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: apiKey))),
                      child: SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: item.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl: service.getImgUrl(item.posterPath),
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                    )
                                  : const Center(child: Icon(Icons.movie, size: 50)),
                            ),
                            const SizedBox(height: 8),
                            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
