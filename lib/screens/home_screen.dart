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
  int _movieTab = 0;
  int _tvTab = 0;

  @override
  void initState() {
    super.initState();
    _service = TMDBService(widget.apiKey);
    _future = _loadHome();
  }

  Future<_HomeData> _loadHome() async {
    final r = await Future.wait([
      _safeLoad(_service.getTrending),
      _safeLoad(_service.getPopularMovies),
      _safeLoad(_service.getPopularTv),
    ]);
    return _HomeData(
      trending: r[0].items,
      popularMovies: r[1].items,
      popularTv: r[2].items,
      errors: [...r[0].errors, ...r[1].errors, ...r[2].errors],
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

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardHi,
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
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text,
                        height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.warn),
                        const SizedBox(width: 4),
                        Text(item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppTheme.text, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                          style: const TextStyle(
                              color: AppTheme.textDim, fontWeight: FontWeight.w500)),
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

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.text : AppTheme.textDim,
          ),
        ),
      ),
    );
  }

  Widget _posterRow(List<MediaItem> items) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) => SizedBox(
          width: 132,
          child: GestureDetector(
            onTap: () => _open(items[i]),
            child: PosterCard(item: items[i], apiKey: widget.apiKey),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required int tab,
    required ValueChanged<int> onTab,
    required String topLabel,
    required String popLabel,
    required List<MediaItem> top,
    required List<MediaItem> popular,
  }) {
    final items = tab == 0 ? (top.isNotEmpty ? top : popular) : (popular.isNotEmpty ? popular : top);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              _tab(topLabel, tab == 0, () => onTab(0)),
              const SizedBox(width: 12),
              _tab(popLabel, tab == 1, () => onTab(1)),
            ],
          ),
        ),
        if (items.isEmpty)
          const SizedBox(
            height: 140,
            child: Center(
              child: Text('Nothing to show yet.', style: TextStyle(color: AppTheme.textDim)),
            ),
          )
        else
          _posterRow(items),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MOVIX',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_off_rounded),
            tooltip: 'Reset API Key',
            onPressed: _showResetDialog,
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
                  FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry')),
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
                  Text(data?.errors.join(' ') ?? 'No catalogs loaded.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textDim)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry')),
                ],
              ),
            );
          }
          final heroItem = data.trending.isNotEmpty
              ? data.trending.first
              : (data.popularMovies.isNotEmpty ? data.popularMovies.first : data.popularTv.first);
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                _hero(heroItem),
                _section(
                  title: 'Trending Movies',
                  tab: _movieTab,
                  onTab: (v) => setState(() => _movieTab = v),
                  topLabel: 'Top Movies',
                  popLabel: 'Popular',
                  top: data.trending.where((m) => m.mediaType == 'movie').toList(),
                  popular: data.popularMovies,
                ),
                _section(
                  title: 'Trending TV Series',
                  tab: _tvTab,
                  onTab: (v) => setState(() => _tvTab = v),
                  topLabel: 'Top Series',
                  popLabel: 'Popular',
                  top: data.popularTv,
                  popular: data.popularTv,
                ),
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
