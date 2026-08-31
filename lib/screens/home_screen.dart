import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'search_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String apiKey;
  final VoidCallback? onResetKey;

  const HomeScreen({
    super.key,
    required this.apiKey,
    this.onResetKey,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TMDBService _service;
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _service = TMDBService(widget.apiKey);
    _future = _loadHome();
  }

  Future<_HomeData> _loadHome() async {
    final trendingFuture = _safeLoad(_service.getTrending);
    final moviesFuture = _safeLoad(_service.getPopularMovies);
    final tvFuture = _safeLoad(_service.getPopularTv);

    final results = await Future.wait([
      trendingFuture,
      moviesFuture,
      tvFuture,
    ]);

    return _HomeData(
      trending: results[0].items,
      popularMovies: results[1].items,
      popularTv: results[2].items,
      errors: [
        ...results[0].errors,
        ...results[1].errors,
        ...results[2].errors,
      ],
    );
  }

  Future<_SafeResult> _safeLoad(Future<List<MediaItem>> Function() loader) async {
    try {
      final items = await loader();
      return _SafeResult(items: items);
    } catch (e) {
      return _SafeResult(items: const [], errors: [e.toString()]);
    }
  }

  void _refresh() {
    setState(() {
      _future = _loadHome();
    });
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(apiKey: widget.apiKey)),
    );
  }

  void _confirmResetKey() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset TMDB API Key?'),
        content: const Text('This will return you to the setup screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResetKey?.call();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey)),
                ),
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: _service.getImgUrl(item.posterPath),
                                  fit: BoxFit.cover,
                                  width: 150,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey.shade900,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade900,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade900,
                                  child: const Center(child: Icon(Icons.movie, size: 50)),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nebula'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.key_off),
            onPressed: _confirmResetKey,
            tooltip: 'Reset API Key',
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading TMDB catalogs...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final data = snapshot.data;
          if (data == null || !data.hasAnyItems) {
            final msg = data?.errors.join('\n\n') ?? 'No data returned.';
            return _ErrorView(
              message: msg.isEmpty ? 'No catalogs loaded.' : msg,
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (data.errors.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Text(
                      'Some catalogs failed:\n${data.errors.join('\n')}',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                _section('Trending This Week', data.trending),
                _section('Popular Movies', data.popularMovies),
                _section('Popular TV Shows', data.popularTv),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orangeAccent),
            const SizedBox(height: 12),
            const Text('Home could not load', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeResult {
  final List<MediaItem> items;
  final List<String> errors;

  const _SafeResult({
    required this.items,
    this.errors = const [],
  });
}

class _HomeData {
  final List<MediaItem> trending;
  final List<MediaItem> popularMovies;
  final List<MediaItem> popularTv;
  final List<String> errors;

  const _HomeData({
    required this.trending,
    required this.popularMovies,
    required this.popularTv,
    required this.errors,
  });

  bool get hasAnyItems => trending.isNotEmpty || popularMovies.isNotEmpty || popularTv.isNotEmpty;
}
