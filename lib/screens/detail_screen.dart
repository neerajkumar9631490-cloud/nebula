import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../services/stremio/catalog_service.dart';
import '../services/watch_progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import '../widgets/source_picker.dart';
import 'addons_screen.dart';
import 'player_screen.dart';

/// Detail screen in the reference style: inline preview player, title +
/// Info sheet, meta strip, action pills, Resources with season dropdown
/// and episode chips, For-you / Comments tabs, recommendation grid and
/// a floating Watch pill — green theme, everything tappable for real.
class DetailScreen extends StatefulWidget {
  final MediaItem item;

  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  static const _listKey = 'movix_watchlist';

  final WatchProgressService _wp = WatchProgressService();
  final CatalogService _catalogs = CatalogService();
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  WatchProgress? _movieProgress;
  Map<String, dynamic>? _meta;
  Map<int, List<int>> _epsBySeason = {};
  late Future<List<MediaItem>> _recsFuture;
  bool _listed = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadMeta();
    _recsFuture = _loadRecs();
    _loadListed();
  }

  Future<void> _loadProgress() async {
    if (widget.item.mediaType != 'tv') {
      final p = await _wp.loadMovie(widget.item.id);
      if (mounted) setState(() => _movieProgress = p);
    }
  }

  /// Full details from a meta plugin: real season/episode lists,
  /// genres and richer artwork. Falls back gracefully when offline.
  Future<void> _loadMeta() async {
    if (widget.item.mediaType != 'tv') return;
    try {
      final meta = await _catalogs.fetchMeta(widget.item);
      if (!mounted) return;
      final bySeason = <int, List<int>>{};
      final videos = meta?['videos'];
      if (videos is List) {
        for (final v in videos.whereType<Map<String, dynamic>>()) {
          final s = (v['season'] as num?)?.toInt() ?? 0;
          final e = (v['episode'] as num?)?.toInt() ??
              (v['number'] as num?)?.toInt() ??
              0;
          if (s > 0 && e > 0) bySeason.putIfAbsent(s, () => <int>[]).add(e);
        }
        for (final k in bySeason.keys) {
          bySeason[k]!.sort();
        }
      }
      setState(() {
        _meta = meta;
        _epsBySeason = bySeason;
        final seasons = _seasonOptions;
        if (!seasons.contains(_selectedSeason)) {
          _selectedSeason = seasons.first;
        }
        final eps = _episodeOptions;
        if (!eps.contains(_selectedEpisode)) {
          _selectedEpisode = eps.first;
        }
      });
    } catch (_) {}
  }

  Future<List<MediaItem>> _loadRecs() async {
    try {
      final sections = await _catalogs.loadSections(catalogsPerType: 1);
      final out = <MediaItem>[];
      for (final s in sections) {
        for (final m in s.items) {
          if (m.id != widget.item.id &&
              m.mediaType == widget.item.mediaType) {
            out.add(m);
          }
          if (out.length >= 12) return out;
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadListed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_listKey);
      var has = false;
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        has = map.containsKey(widget.item.id);
      }
      if (mounted) setState(() => _listed = has);
    } catch (_) {}
  }

  Future<void> _toggleListed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> map = {};
      final raw = prefs.getString(_listKey);
      if (raw != null) {
        try {
          map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }
      final it = widget.item;
      if (map.containsKey(it.id)) {
        map.remove(it.id);
      } else {
        map[it.id] = {
          't': it.title,
          'm': it.mediaType,
          'p': it.posterPath,
          'b': it.backdropPath,
          'y': it.releaseYear,
          'r': it.rating,
          'o': it.overview,
        };
      }
      await prefs.setString(_listKey, jsonEncode(map));
      if (!mounted) return;
      setState(() => _listed = map.containsKey(it.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_listed ? 'Added to your list' : 'Removed from your list')),
      );
    } catch (_) {}
  }

  void _share() {
    final it = widget.item;
    final text =
        it.releaseYear.isEmpty ? it.title : '${it.title} (${it.releaseYear})';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Title copied to clipboard')),
    );
  }

  List<int> get _seasonOptions {
    final s = _epsBySeason.keys.toList()..sort();
    return s.isEmpty ? List.generate(5, (i) => i + 1) : s;
  }

  List<int> get _episodeOptions {
    final eps = _epsBySeason[_selectedSeason];
    if (eps == null || eps.isEmpty) return List.generate(20, (i) => i + 1);
    return eps;
  }

  List<String> get _genres {
    final g = _meta?['genres'];
    if (g is! List) return const [];
    return g.whereType<String>().take(4).toList();
  }

  bool get _isTv => widget.item.mediaType == 'tv';

  /// Source choice happens in-place (bottom sheet) instead of a
  /// separate results page — pick, then play straight away.
  Future<void> _openSources() async {
    final result = await showSourcePicker(
      context: context,
      item: widget.item,
      season: _selectedSeason,
      episode: _selectedEpisode,
    );
    if (result == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          result: result,
          title: _isTv
              ? '${widget.item.title} • S$_selectedSeason E$_selectedEpisode'
              : widget.item.title,
          item: widget.item,
          season: _isTv ? _selectedSeason : null,
          episode: _isTv ? _selectedEpisode : null,
        ),
      ),
    ).then((_) => _loadProgress());
  }

  void _playEpisode(int episode) {
    setState(() => _selectedEpisode = episode);
    _openSources();
  }

  void _showInfo() {
    final it = widget.item;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(c).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(it.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (it.releaseYear.isNotEmpty) _chip(it.releaseYear),
                  _chip(it.mediaType.toUpperCase()),
                  if (it.rating > 0)
                    _chip(it.rating.toStringAsFixed(1),
                        icon: Icons.star_rounded),
                  ..._genres.map(_chip),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Storyline',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              const SizedBox(height: 6),
              Text(
                it.overview.isEmpty
                    ? 'No overview available for this title yet.'
                    : it.overview,
                style: const TextStyle(
                    color: AppTheme.textDim, height: 1.6, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(c).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How streaming works',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              const SizedBox(height: 12),
              const _HelpRow(
                  n: '1',
                  t: 'Pick an episode (series) or just press Watch.'),
              const _HelpRow(
                  n: '2',
                  t: 'Choose a source — healthiest streams are listed first.'),
              const _HelpRow(
                  n: '3', t: 'Playback starts; progress is saved automatically.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddonsScreen()));
                  },
                  icon: const Icon(Icons.extension_rounded),
                  label: const Text('Manage add-ons'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.star),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    final hasBackdrop = widget.item.backdropPath != null;
    return Scaffold(
      // Pure black canvas like a cinema — artwork carries the color.
      backgroundColor: Colors.black,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Pressable(
        onTap: _openSources,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 15),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppTheme.glowShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: AppTheme.onAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                _isTv
                    ? 'Watch S$_selectedSeason E$_selectedEpisode'
                    : 'Watch Now',
                style: const TextStyle(
                    color: AppTheme.onAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(statusH, hasBackdrop),
            _titleRow(),
            _metaLine(),
            _pillsRow(),
            _resumeStrip(),
            _resources(),
            _tabs(),
            SizedBox(height: 110 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ── Inline preview player ────────────────────────────────
  Widget _preview(double statusH, bool hasBackdrop) {
    final art = hasBackdrop
        ? widget.item.backdropPath
        : widget.item.posterPath;
    return Stack(
      children: [
        Column(
          children: [
            // Status-bar strip stays solid black so no artwork (and no
            // cutoff) ever hides under the clock/signal icons.
            Container(height: statusH, color: Colors.black),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (art != null)
                    CachedNetworkImage(
                      imageUrl: art,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 1000,
                      fadeInDuration: AppTheme.med,
                      placeholder: (c, u) =>
                          Container(color: AppTheme.bgHi),
                      errorWidget: (c, u, e) =>
                          Container(color: AppTheme.bgHi),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0B1F15), Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showHelp,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline_rounded,
                              color: Colors.white, size: 24),
                          SizedBox(height: 1),
                          Text('Help',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          top: statusH,
          child: Center(
            child: Pressable(
              onTap: _openSources,
              // Flat white player button — like a real video player.
              // The floating Watch pill keeps the single glow on screen.
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 34),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Title + Info ─────────────────────────────────────────
  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text,
                  letterSpacing: -0.3),
            ),
          ),
          GestureDetector(
            onTap: _showInfo,
            child: const Padding(
              padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Info',
                      style: TextStyle(
                          color: AppTheme.textDim, fontSize: 14)),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textDim, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Meta strip ───────────────────────────────────────────
  Widget _metaLine() {
    const sep = Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text('|',
          style: TextStyle(color: AppTheme.textFaint, fontSize: 13)),
    );
    final seasonCount = _epsBySeason.keys.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Icon(_isTv ? Icons.tv_rounded : Icons.movie_rounded,
              size: 15, color: AppTheme.textDim),
          if (widget.item.rating > 0) ...[
            sep,
            const Icon(Icons.star_rounded,
                size: 15, color: AppTheme.star),
            Text(widget.item.rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: AppTheme.star,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
          if (widget.item.releaseYear.isNotEmpty) ...[
            sep,
            Text(widget.item.releaseYear,
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 14)),
          ],
          if (_genres.isNotEmpty) ...[
            sep,
            Text(_genres.first,
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 14)),
          ],
          if (_isTv && seasonCount > 0) ...[
            sep,
            Text('$seasonCount season${seasonCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  // ── Action pills ─────────────────────────────────────────
  Widget _pillsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          _pill(
            label: _listed ? 'Listed' : 'Add to list',
            icon: _listed
                ? Icons.check_rounded
                : Icons.playlist_add_rounded,
            onTap: _toggleListed,
            highlighted: _listed,
          ),
          const SizedBox(width: 10),
          _pill(
            label: 'Share',
            icon: Icons.share_rounded,
            onTap: _share,
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: highlighted
                  ? AppTheme.accent.withOpacity(0.6)
                  : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 19,
                color: highlighted
                    ? AppTheme.accent
                    : AppTheme.text),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: highlighted
                        ? AppTheme.accent
                        : AppTheme.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Continue watching strip (movies) ─────────────────────
  Widget _resumeStrip() {
    final p = _movieProgress;
    if (_isTv || p == null || !p.isResumable) {
      return const SizedBox.shrink();
    }
    final pct = p.durationMs > 0
        ? (p.positionMs / p.durationMs).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Pressable(
        onTap: _openSources,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_rounded,
                  color: AppTheme.accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Continue watching',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                            fontSize: 13.5)),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4.5,
                        backgroundColor:
                            Colors.white.withOpacity(0.12),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                AppTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                        '${(pct * 100).toStringAsFixed(0)}% watched • ${p.positionLabel}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textDim),
            ],
          ),
        ),
      ),
    );
  }

  // ── Resources: season dropdown + episode chips ────────────
  Widget _resources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Text('Resources',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Streams via your add-ons',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textDim, fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddonsScreen())),
                child: const Icon(Icons.help_outline_rounded,
                    color: AppTheme.textDim, size: 20),
              ),
            ],
          ),
        ),
        if (_isTv)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.strokeHi),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSeason,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textDim),
                  borderRadius: BorderRadius.circular(14),
                  items: _seasonOptions
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                              'Season ${s.toString().padLeft(2, '0')}')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedSeason = v ?? 1;
                    final eps = _episodeOptions;
                    _selectedEpisode =
                        eps.contains(_selectedEpisode)
                            ? _selectedEpisode
                            : eps.first;
                  }),
                ),
              ),
            ),
          ),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            itemCount: _isTv ? _episodeOptions.length + 1 : 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (c, i) {
              if (!_isTv) {
                return _episodeChip('Full Movie', true, _openSources,
                    wide: true);
              }
              if (i == 0) {
                return _episodeChip('All', false, _openSources);
              }
              final e = _episodeOptions[i - 1];
              final label = e.toString().padLeft(2, '0');
              return _episodeChip(
                  label, e == _selectedEpisode, () => _playEpisode(e));
            },
          ),
        ),
      ],
    );
  }

  Widget _episodeChip(String label, bool selected, VoidCallback onTap,
      {bool wide = false}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        // Number chips keep the fixed square; word labels (Full Movie)
        // size to their text with comfortable padding — never wrapped.
        width: wide ? null : 72,
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 22)
            : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.accentGradient : null,
          color: selected ? null : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            softWrap: false,
            style: TextStyle(
                color: selected
                    ? AppTheme.onAccent
                    : AppTheme.textDim,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ),
    );
  }

  // ── Tabs: For you / Comments ─────────────────────────────
  Widget _tabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              _tabBtn('For you', 0),
              const SizedBox(width: 26),
              _tabBtn('Comments', 1, dot: true),
            ],
          ),
        ),
        const Divider(height: 24, color: AppTheme.stroke),
        if (_tab == 0) _forYou() else _commentsEmpty(),
      ],
    );
  }

  Widget _tabBtn(String label, int index, {bool dot = false}) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? AppTheme.text
                          : AppTheme.textDim)),
              if (dot) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 3,
              width: 34,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3)),
            )
          else
            const SizedBox(height: 9),
        ],
      ),
    );
  }

  Widget _forYou() {
    return FutureBuilder<List<MediaItem>>(
      future: _recsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) => const ShimmerBox(
                  width: 118, height: 177, radius: 14),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Nothing similar found yet.',
                style: TextStyle(
                    color: AppTheme.textDim, fontSize: 13.5)),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.52,
          ),
          itemCount: items.length,
          itemBuilder: (c, i) => Pressable(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetailScreen(item: items[i])),
            ),
            child: PosterCard(item: items[i]),
          ),
        );
      },
    );
  }

  Widget _commentsEmpty() {
    // Optically centered in the remaining viewport so the block never
    // clings to the tab divider with dead space below it.
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: AppTheme.textFaint),
              SizedBox(height: 10),
              Text('No comments yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                      fontSize: 15)),
              SizedBox(height: 4),
              Text('Be the first to share your thoughts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textDim, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String n;
  final String t;
  const _HelpRow({required this.n, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(t,
                  style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 13.5,
                      height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
