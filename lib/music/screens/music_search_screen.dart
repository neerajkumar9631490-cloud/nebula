import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/section_header.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';
import '../services/music_provider.dart';
import '../services/music_service.dart';
import 'music_player_screen.dart';
import '../widgets/track_tile.dart';

/// Music search with debounce: tracks, artists and albums in sections.
/// Tapping a track plays it inside the full result queue.
class MusicSearchScreen extends StatefulWidget {
  const MusicSearchScreen({super.key});

  @override
  State<MusicSearchScreen> createState() => _MusicSearchScreenState();
}

class _MusicSearchScreenState extends State<MusicSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _service = MusicService();
  final _player = MusicPlayerController();
  Timer? _debounce;
  MusicSearchResult? _results;
  bool _loading = false;
  bool _searched = false;

  static const List<String> _suggestions = [
    'Arijit Singh',
    'Taylor Swift',
    'Anirudh',
    'Drake',
    'Shreya Ghoshal',
    'BTS',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = null;
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
      final results = await _service.searchAll(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = const MusicSearchResult();
          _loading = false;
        });
      }
    }
  }

  void _playTracks(List<Track> tracks, int index) {
    _player.playTracks(tracks, startIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  Future<void> _artistTop(Artist artist) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => _ArtistTopSheet(artist: artist),
    );
  }

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
                  ? _loadingBody(key: const ValueKey('loading'))
                  : !_searched
                      ? _suggestBody(key: const ValueKey('suggest'))
                      : (_results == null || _results!.isEmpty
                          ? _emptyBody(key: const ValueKey('empty'))
                          : _resultsBody(_results!,
                              key: const ValueKey('results'))),
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
                        color: _focus.hasFocus
                            ? AppTheme.accent
                            : AppTheme.stroke),
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
                          style: const TextStyle(
                              color: AppTheme.text, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Songs, artists, albums…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 13),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(
                                        Icons.clear_rounded,
                                        color: AppTheme.textDim,
                                        size: 19),
                                    onPressed: () {
                                      _controller.clear();
                                      _search('');
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
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

  Widget _suggestBody({Key? key}) {
    return ListView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
          bottom: 100 + MediaQuery.of(context).padding.bottom),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text('Try searching',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text)),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
              'Results stream instantly as 30-second previews.',
              style: TextStyle(fontSize: 13, color: AppTheme.textDim)),
        ),
      ],
    );
  }

  Widget _loadingBody({Key? key}) {
    return ListView.separated(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) => const Row(
        children: [
          ShimmerBox(width: 52, height: 52, radius: 10),
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

  Widget _emptyBody({Key? key}) {
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
              child: const Icon(Icons.music_off_rounded,
                  size: 40, color: AppTheme.textDim),
            ),
            const SizedBox(height: 16),
            const Text('No results found',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text)),
            const SizedBox(height: 6),
            Text('Try “${_controller.text.trim()}” spelled differently.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textDim, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _resultsBody(MusicSearchResult r, {Key? key}) {
    return ListView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 100 + MediaQuery.of(context).padding.bottom),
      children: [
        if (r.tracks.isNotEmpty) ...[
          const SectionHeader(title: 'Tracks'),
          for (var i = 0; i < r.tracks.length; i++) ...[
            TrackTile(
              track: r.tracks[i],
              onTap: () => _playTracks(r.tracks, i),
            ),
            if (i < r.tracks.length - 1) const SizedBox(height: 10),
          ],
        ],
        if (r.artists.isNotEmpty) ...[
          const SectionHeader(title: 'Artists'),
          for (final a in r.artists)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () => _artistTop(a),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surface,
                        ),
                        child: ClipOval(
                          child: a.artwork.isEmpty
                              ? const Center(
                                  child: Icon(Icons.person_rounded,
                                      color: AppTheme.textDim,
                                      size: 24),
                                )
                              : CachedNetworkImage(
                                  imageUrl: a.artwork,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  fadeInDuration: AppTheme.fast,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text)),
                            Text(a.source == 'deezer'
                                ? 'Artist • tap for top tracks'
                                : 'Artist',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textDim),
                    ],
                  ),
                ),
              ),
            ),
        ],
        if (r.albums.isNotEmpty) ...[
          const SectionHeader(title: 'Albums'),
          for (final a in r.albums)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () {
                  _controller.text = a.title;
                  _search(a.title);
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.surface,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: a.artwork.isEmpty
                              ? const Center(
                                  child: Icon(Icons.album_rounded,
                                      color: AppTheme.textDim,
                                      size: 24),
                                )
                              : CachedNetworkImage(
                                  imageUrl: a.artwork,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  fadeInDuration: AppTheme.fast,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text)),
                            Text(
                                a.artist.isEmpty
                                    ? 'Album'
                                    : a.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textDim),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Bottom sheet with an artist's top tracks (Deezer).
class _ArtistTopSheet extends StatefulWidget {
  final Artist artist;
  const _ArtistTopSheet({required this.artist});

  @override
  State<_ArtistTopSheet> createState() => _ArtistTopSheetState();
}

class _ArtistTopSheetState extends State<_ArtistTopSheet> {
  late Future<List<Track>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        DeezerMusicProvider().artistTopTracks(widget.artist.id, limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              const Text('Top tracks',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textDim)),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Track>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final tracks = snapshot.data ?? [];
                    if (tracks.isEmpty) {
                      return const Center(
                        child: Text('No top tracks found.',
                            style: TextStyle(
                                color: AppTheme.textDim)),
                      );
                    }
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (c, i) => TrackTile(
                        track: tracks[i],
                        onTap: () {
                          player.playTracks(tracks, startIndex: i);
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MusicPlayerScreen()),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
