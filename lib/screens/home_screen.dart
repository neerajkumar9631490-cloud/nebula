import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';
import 'addons_screen.dart';
import 'detail_screen.dart';
import 'search_screen.dart';

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
  int _tab = 0;
  int _movieChip = 0;
  int _tvChip = 0;

  static const List<String> _tabs = ['Trending', 'Movies', 'TV'];
  static const List<String> _movieChips = ['Top Movies', 'Popular'];
  static const List<String> _tvChips = ['Top Series', 'Popular'];

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
      context, MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey)));

  List<MediaItem> _heroList(_HomeData d) =>
      _tab == 1 ? d.popularMovies : _tab == 2 ? d.popularTv : d.trending;

  List<MediaItem> _movieList(_HomeData d) => _movieChip == 0
      ? d.trending.where((m) => m.mediaType == 'movie').toList()
      : d.popularMovies;

  List<MediaItem> _tvList(_HomeData d) =>
      _tvChip == 0 ? d.trending.where((m) => m.mediaType == 'tv').toList() : d.popularTv;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _errorView();
            }
            final data = snapshot.data;
            if (data == null || !data.hasAnyItems) {
              return _errorView();
            }
            final heroList = _heroList(data);
            return ListView(
              children: [
                _topBar(),
                _tabRow(),
                if (heroList.isNotEmpty) ...[
                  _hero(heroList.first),
                  const SizedBox(height: 10),
                  _heroCarousel(heroList),
                ],
                SectionHeader(title: 'Trending Movies'),
                _chips(_movieChips, _movieChip, (i) => setState(() => _movieChip = i)),
                const SizedBox(height: 10),
                _rankRow(_movieList(data)),
                SectionHeader(title: 'Trending TV Series'),
                _chips(_tvChips, _tvChip, (i) => setState(() => _tvChip = i)),
                const SizedBox(height: 10),
                _rankRow(_tvList(data)),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: AppTheme.textDim),
          const SizedBox(height: 12),
          const Text('Home could not load', style: TextStyle(color: AppTheme.textDim)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.glassGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Icon(Icons.movie_filter_rounded, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => SearchScreen(apiKey: widget.apiKey))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search_rounded, color: AppTheme.textDim, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Search movies, TV shows…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textDim, fontSize: 14)),
                      ),
                      Text('Search',
                          style: TextStyle(
                              color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AddonsScreen())),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle),
                child: const Icon(Icons.extension_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabRow() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 22),
        itemBuilder: (c, i) {
          final selected = i == _tab;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _tabs[i],
                  style: TextStyle(
                    fontSize: selected ? 17 : 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppTheme.text : AppTheme.textDim,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: selected ? 28 : 0,
                  decoration:
                      BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(MediaItem item) {
    final backdrop = item.backdropPath != null ? _service.getImgUrl(item.backdropPath) : null;
    return GestureDetector(
      onTap: () => _open(item),
      child: SizedBox(
        height: 300,
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
                    AppTheme.bg.withOpacity(0.6),
                    AppTheme.bg,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 15, color: AppTheme.star),
                        const SizedBox(width: 4),
                        Text(item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppTheme.star,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(width: 10),
                      ],
                      Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                          style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
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

  Widget _heroCarousel(List<MediaItem> items) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => _open(item),
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 80,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.cardHi),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: _service.getImgUrl(item.posterPath),
                              fit: BoxFit.cover,
                              memCacheWidth: 120)
                          : const Center(child: Icon(Icons.movie_outlined, color: AppTheme.textDim)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(item.mediaType == 'tv' ? Icons.tv_rounded : Icons.movie_rounded,
                                size: 14, color: AppTheme.textDim),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.accent, Color(0xFF1FB6A5)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppTheme.onAccent, size: 22),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chips(List<String> chips, int selected, ValueChanged<int> onTap) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? AppTheme.cardHi : AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AppTheme.accent.withOpacity(0.5) : AppTheme.stroke),
              ),
              child: Text(chips[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? AppTheme.text : AppTheme.textDim)),
            ),
          );
        },
      ),
    );
  }

  Widget _rankRow(List<MediaItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('No items found', style: TextStyle(color: AppTheme.textDim)),
      );
    }
    return SizedBox(
      height: 268,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) => SizedBox(
          width: 138,
          child: GestureDetector(
            onTap: () => _open(items[i]),
            child: PosterCard(item: items[i], apiKey: widget.apiKey, rank: i + 1),
          ),
        ),
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
  const _HomeData(
      {required this.trending,
      required this.popularMovies,
      required this.popularTv,
      required this.errors});
  bool get hasAnyItems =>
      trending.isNotEmpty || popularMovies.isNotEmpty || popularTv.isNotEmpty;
}
