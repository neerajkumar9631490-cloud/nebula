import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/section_header.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';
import '../services/music_service.dart';
import 'music_player_screen.dart';
import 'music_search_screen.dart';
import '../widgets/browse_sheets.dart';
import '../widgets/playlist_sheet.dart';

/// Music home: charts per provider, recently played, liked tracks
/// and local playlists. Tapping any card plays its list as a queue.
class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key});

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  final _controller = MusicPlayerController();
  final _service = MusicService();
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      _service.featuredSections().catchError((_) => <String, List<Track>>{}),
      _service.genres().catchError((_) => <MusicGenre>[]),
      _service
          .chartPlaylists(limit: 10)
          .catchError((_) => <RemotePlaylist>[]),
      _controller.recentPlayed(limit: 12).catchError((_) => <Track>[]),
      _controller.likedTracks().catchError((_) => <String, Track>{}),
      _controller.playlists().catchError((_) => <Playlist>[]),
    ]);
    return _HomeData(
      featured: results[0] as Map<String, List<Track>>,
      genres: results[1] as List<MusicGenre>,
      curated: results[2] as List<RemotePlaylist>,
      recent: results[3] as List<Track>,
      liked: (results[4] as Map<String, Track>).values.toList(),
      playlists: results[5] as List<Playlist>,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  void _playList(List<Track> tracks, int index) {
    _controller.playTracks(tracks, startIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  void _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicSearchScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                    bottom:
                        110 + MediaQuery.of(context).padding.bottom),
                children: const [
                  _HomeSkeleton(),
                ],
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 44, color: AppTheme.textDim),
                    const SizedBox(height: 12),
                    const Text('Music is unavailable offline',
                        style: TextStyle(color: AppTheme.textDim)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry')),
                  ],
                ),
              );
            }
            return ListView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(
                  bottom: 110 + MediaQuery.of(context).padding.bottom),
              children: [
                _header(),
                if (data.recent.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Recently played',
                      subtitle: 'Jump back in'),
                  _cardRow(data.recent,
                      (t, i) => _playList(data.recent, i)),
                ],
                for (final entry in data.featured.entries) ...[
                  SectionHeader(
                      title: entry.key, subtitle: 'Curated for you'),
                  _cardRow(entry.value,
                      (t, i) => _playList(entry.value, i)),
                ],
                if (data.genres.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Genres', subtitle: 'Find your mood'),
                  _genreRow(data.genres),
                ],
                if (data.curated.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Playlists to explore',
                      subtitle: 'Curated collections'),
                  _curatedRow(data.curated),
                ],
                const SectionHeader(
                    title: 'Your library', subtitle: 'Likes & playlists'),
                _libraryRow(data),
                if (data.recent.isEmpty && data.featured.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                        'Connect to the internet to browse music.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textDim)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.glowShadow,
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: AppTheme.onAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Music',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text)),
                  Text('30-second previews that play instantly',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textDim)),
                ],
              ),
            ),
            IconButton(
              onPressed: _openSearch,
              icon: const Icon(Icons.search_rounded,
                  color: AppTheme.text, size: 26),
              tooltip: 'Search music',
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRow(
      List<Track> tracks, void Function(Track, int) onTap) {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (c, i) {
          final t = tracks[i];
          return Pressable(
            onTap: () => onTap(t, i),
            child: SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.surface,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: t.artworkSmall.isEmpty
                          ? const Center(
                              child: Icon(Icons.music_note_rounded,
                                  color: AppTheme.textDim, size: 30),
                            )
                          : CachedNetworkImage(
                              imageUrl: t.artworkSmall,
                              fit: BoxFit.cover,
                              memCacheWidth: 260,
                              fadeInDuration: AppTheme.fast,
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text)),
                  Text(t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textDim)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _genreRow(List<MusicGenre> genres) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final g = genres[i];
          return Pressable(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MusicSearchScreen(initialQuery: '${g.name} hits'),
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: Text(g.name,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
            ),
          );
        },
      ),
    );
  }

  Widget _curatedRow(List<RemotePlaylist> playlists) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (c, i) {
          final p = playlists[i];
          return Pressable(
            onTap: () => showRemotePlaylistSheet(context, p),
            child: SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 128,
                    height: 118,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.surface,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: p.artwork.isEmpty
                          ? const Center(
                              child: Icon(
                                  Icons.queue_music_rounded,
                                  color: AppTheme.textDim,
                                  size: 30),
                            )
                          : CachedNetworkImage(
                              imageUrl: p.artwork,
                              fit: BoxFit.cover,
                              memCacheWidth: 260,
                              fadeInDuration: AppTheme.fast,
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text)),
                  Text(
                      p.trackCount > 0
                          ? '${p.trackCount} tracks'
                          : 'Playlist',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textDim)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _libraryRow(_HomeData data) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _libCard(
            icon: Icons.favorite_rounded,
            title: 'Liked',
            subtitle: '${data.liked.length} tracks',
            onTap: () => showPlaylistSheet(
              context,
              Playlist(
                  id: '__liked__',
                  name: 'Liked tracks',
                  tracks: data.liked),
              readOnly: true,
            ).then((_) => _refresh()),
          ),
          const SizedBox(width: 12),
          for (final pl in data.playlists) ...[
            _libCard(
              icon: Icons.queue_music_rounded,
              title: pl.name,
              subtitle: '${pl.tracks.length} tracks',
              onTap: () => showPlaylistSheet(context, pl)
                  .then((_) => _refresh()),
            ),
            const SizedBox(width: 12),
          ],
          _libCard(
            icon: Icons.add_rounded,
            title: 'New',
            subtitle: 'Create playlist',
            dashed: true,
            onTap: () async {
              final name = await askPlaylistName(context);
              if (name == null || !mounted) return;
              await _controller.createPlaylist(name);
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _libCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool dashed = false,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accent, size: 26),
            const SizedBox(height: 10),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                    fontSize: 14)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HomeData {
  final Map<String, List<Track>> featured;
  final List<MusicGenre> genres;
  final List<RemotePlaylist> curated;
  final List<Track> recent;
  final List<Track> liked;
  final List<Playlist> playlists;

  const _HomeData({
    required this.featured,
    required this.genres,
    required this.curated,
    required this.recent,
    required this.liked,
    required this.playlists,
  });
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 90),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: ShimmerBox(width: 180, height: 22, radius: 8),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: Row(
            children: [
              SizedBox(width: 20),
              ShimmerBox(width: 128, height: 188, radius: 16),
              SizedBox(width: 13),
              ShimmerBox(width: 128, height: 188, radius: 16),
              SizedBox(width: 13),
              ShimmerBox(width: 128, height: 188, radius: 16),
            ],
          ),
        ),
      ],
    );
  }
}
