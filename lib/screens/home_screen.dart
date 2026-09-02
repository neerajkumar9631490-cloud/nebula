import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String apiKey;
  final VoidCallback? onResetKey;

  const HomeScreen({super.key, required this.apiKey, this.onResetKey});

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
    final results = await Future.wait([
      _safeLoad(_service.getTrending),
      _safeLoad(_service.getPopularMovies),
      _safeLoad(_service.getPopularTv),
    ]);
    return _HomeData(
      trending: results[0].items,
      popularMovies: results[1].items,
      popularTv: results[2].items,
      errors: [...results[0].errors, ...results[1].errors, ...results[2].errors],
    );
  }

  Future<_SafeResult> _safeLoad(Future<List<MediaItem>> Function() loader) async {
    try {
      return _SafeResult(items: await loader());
    } catch (e) {
      return _SafeResult(items: const [], errors: [e.toString()]);
    }
  }

  void _refresh() => setState(() => _future = _loadHome());

  void _open(MediaItem item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey)),
      );

  Widget _hero(MediaItem item) {
    final backdrop = item.backdropPath != null ? _service.getImgUrl(item.backdropPath) : null;
    return GestureDetector(
      onTap: () => _open(item),
      child: SizedBox(
        height: 430,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null)
              CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover, memCacheWidth: 900),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.bg.withOpacity(0.05),
                    AppTheme.bg.withOpacity(0.8),
                    AppTheme.bg,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.bg.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.text, height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.warn),
                        const SizedBox(width: 4),
                        Text(item.rating.toStringAsFixed(1),
                            style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                          style: const TextStyle(color: AppTheme.textDim, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _open(item),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Watch'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _open(item),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.stroke),
                          foregroundColor: AppTheme.text,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.text)),
        ),
        SizedBox(
          height: 132 * 1.5 + 30,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (c, i) => SizedBox(
              width: 132,
              child: GestureDetector(onTap: () => _open(items[i]), child: PosterCard(item: items[i], apiKey: widget.apiKey)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MOVIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_off_rounded),
            tooltip: 'Reset API Key',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppTheme.cardHi,
                title: const Text('Reset TMDB API Key?'),
                content: const Text('This will return you to the setup screen.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResetKey?.call();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44, color: AppTheme.warn),
                  const SizedBox(height: 12),
                  const Text('Home could not load'),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            );
          }
          final data = snapshot.data;
          if (data == null || !data.hasAnyItems) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 44, color: AppTheme.textDim),
                  const SizedBox(height: 12),
                  Text(data?.errors.join('\n') ?? 'No catalogs loaded.',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textDim)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            );
          }

          final heroItem = data.trending.isNotEmpty ? data.trending.first : data.popularMovies.first;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                _hero(heroItem),
                _row('Trending This Week', data.trending),
                _row('Popular Movies', data.popularMovies),
                _row('Popular TV Shows', data.popularTv),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SafeResult {
  final List<MediaItem> items;
  final List<String> errors;
  const _SafeResult({required this.items, this.errors = const []});
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

  bool get hasAnyItems =>
      trending.isNotEmpty || popularMovies.isNotEmpty || popularTv.isNotEmpty;
}
