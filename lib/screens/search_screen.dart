import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String apiKey;
  const SearchScreen({super.key, required this.apiKey});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<MediaItem> _results = [];
  List<MediaItem> _hot = [];
  List<String> _recent = [];
  bool _loading = false;
  bool _searched = false;
  late TMDBService _service;

  static const List<String> _suggestions = [
    'Interstellar',
    'Jujutsu Kaisen',
    'Dhurandhar',
    'The Runner',
    'Mushoku Tensei',
    'Alpha',
  ];

  @override
  void initState() {
    super.initState();
    _service = TMDBService(widget.apiKey);
    _loadRecent();
    _loadHot();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recent = prefs.getStringList('recent_searches') ?? []);
  }

  Future<void> _saveRecent(String q) async {
    final list = List<String>.from(_recent)..remove(q);
    list.insert(0, q);
    _recent = list.take(8).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', _recent);
    if (mounted) setState(() {});
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    if (mounted) setState(() => _recent = []);
  }

  Future<void> _loadHot() async {
    try {
      final r = await _service.getPopularMovies();
      if (mounted) setState(() => _hot = r);
    } catch (_) {}
  }

  void _onChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query, save: false));
  }

  Future<void> _search(String query, {bool save = true}) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final results = await _service.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      if (save && results.isNotEmpty) _saveRecent(q);
      if (save && results.isEmpty) _saveRecent(q);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(MediaItem item) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.med,
              switchInCurve: AppTheme.curve,
              child: _loading
                  ? _loadingSkeleton(key: const ValueKey('loading'))
                  : _searched
                      ? (_results.isEmpty
                          ? _emptyResults(key: const ValueKey('empty'))
                          : _resultsList(key: const ValueKey('results')))
                      : _discover(key: const ValueKey('discover')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE6070B12),
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _focus.hasFocus ? AppTheme.accent : AppTheme.stroke),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Icon(Icons.search_rounded,
                            color: AppTheme.textDim, size: 21),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          onChanged: _onChanged,
                          onSubmitted: (q) => _search(q),
                          onTap: () => setState(() {}),
                          style: const TextStyle(color: AppTheme.text, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Movies, TV shows, anime…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 13),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        color: AppTheme.textDim, size: 19),
                                    onPressed: () {
                                      _controller.clear();
                                      _search('', save: false);
                                      setState(() {});
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                onTap: () => _search(_controller.text),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Go',
                      style: TextStyle(
                          color: AppTheme.onAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discover({Key? key}) {
    return ListView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: 100 + MediaQuery.of(context).padding.bottom),
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                const Text('Recent',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearRecent,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textDim,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recent
                  .map((q) => ActionChip(
                        label: Text(q),
                        avatar: const Icon(Icons.history_rounded,
                            size: 15, color: AppTheme.textDim),
                        onPressed: () {
                          _controller.text = q;
                          _search(q);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A2F).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFF7A2F), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Everyone is searching',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text)),
                    Text('Tap to explore instantly',
                        style: TextStyle(fontSize: 12, color: AppTheme.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((q) => ActionChip(
                      label: Text(q),
                      onPressed: () {
                        _controller.text = q;
                        _search(q);
                      },
                    ))
                .toList(),
          ),
        ),
        const SectionHeader(
            title: 'Hot Movies', subtitle: 'Trending this week worldwide'),
        if (_hot.isEmpty)
          const PosterRowSkeleton(count: 5)
        else
          SizedBox(
            height: 262,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _hot.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (c, i) => SizedBox(
                width: 138,
                child: Pressable(
                  onTap: () => _open(_hot[i]),
                  child: PosterCard(item: _hot[i], apiKey: widget.apiKey, rank: i + 1),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _loadingSkeleton({Key? key}) {
    return ListView.separated(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) => const Row(
        children: [
          ShimmerBox(width: 62, height: 92, radius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 14, radius: 6),
                SizedBox(height: 8),
                ShimmerBox(width: 140, height: 11, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyResults({Key? key}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 40, color: AppTheme.textDim),
            ),
            const SizedBox(height: 16),
            const Text('No results found',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text)),
            const SizedBox(height: 6),
            Text('Try “${_controller.text.trim()}” with different spelling.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _resultsList({Key? key}) {
    return ListView.separated(
      key: key,
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 100 + MediaQuery.of(context).padding.bottom),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final item = _results[i];
        return Pressable(
          onTap: () => _open(item),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'poster-${item.id}',
                  child: Container(
                    width: 60,
                    height: 88,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppTheme.surface),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: _service.getImgUrl(item.posterPath),
                              fit: BoxFit.cover,
                              memCacheWidth: 140,
                              fadeInDuration: AppTheme.fast,
                            )
                          : const Center(
                              child: Icon(Icons.movie_outlined,
                                  color: AppTheme.textDim)),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                              height: 1.25)),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 13, color: AppTheme.star),
                                const SizedBox(width: 3),
                                Text(item.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                '${item.releaseYear} • ${item.mediaType.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textDim)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppTheme.onAccent, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
