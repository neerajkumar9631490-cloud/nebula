import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
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
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recent = []);
  }

  Future<void> _loadHot() async {
    final r = await _service.getPopularMovies();
    if (mounted) setState(() => _hot = r);
  }

  void _onChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query, save: false));
  }

  Future<void> _search(String query, {bool save = true}) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await _service.search(q);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
      if (save) _saveRecent(q);
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _searched
                    ? (_results.isEmpty
                        ? const Center(
                            child: Text('No results found',
                                style: TextStyle(color: AppTheme.textDim)))
                        : _resultsList())
                    : _discover(),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                onSubmitted: (q) => _search(q),
                style: const TextStyle(color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: 'Movies, TV shows, anime…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textDim),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppTheme.textDim, size: 20),
                    onPressed: () {
                      _controller.clear();
                      _search('', save: false);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _search(_controller.text),
              child: const Text('Search',
                  style: TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: AppTheme.textDim),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Voice search is not available on this device.'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discover() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Text('Recent',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearRecent,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Clear'),
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
                      onPressed: () {
                        _controller.text = q;
                        _search(q);
                      }))
                  .toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(
            children: const [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF7A2F), size: 20),
              SizedBox(width: 6),
              Text('Everyone is searching',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text)),
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
                    }))
                .toList(),
          ),
        ),
        SectionHeader(title: 'Hot Movies'),
        SizedBox(
          height: 268,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _hot.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (c, i) => SizedBox(
              width: 138,
              child: GestureDetector(
                onTap: () => _open(_hot[i]),
                child: PosterCard(item: _hot[i], apiKey: widget.apiKey, rank: i + 1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) {
        final item = _results[i];
        return GestureDetector(
          onTap: () => _open(item),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 92,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10), color: AppTheme.cardHi),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.posterPath != null
                            ? CachedNetworkImage(
                                imageUrl: _service.getImgUrl(item.posterPath),
                                fit: BoxFit.cover,
                                memCacheWidth: 140)
                            : const Center(
                                child: Icon(Icons.movie_outlined, color: AppTheme.textDim)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: const Color(0xAA000000),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              item.mediaType == 'tv' ? 'TV' : 'MOVIE',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.text),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppTheme.star),
                          const SizedBox(width: 4),
                          Text(item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: AppTheme.star,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          const SizedBox(width: 8),
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
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppTheme.cardHi, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: AppTheme.text, size: 22),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
