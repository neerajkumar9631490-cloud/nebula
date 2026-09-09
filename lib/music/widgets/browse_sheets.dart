import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';
import '../screens/music_player_screen.dart';
import '../services/music_service.dart';
import 'track_tile.dart';

/// Artist details: top tracks, albums and related artists.
/// Albums drill into [showAlbumSheet]; related artists reopen this sheet.
Future<void> showArtistSheet(BuildContext context, Artist artist) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _ArtistSheetBody(
      artist: artist,
      parentContext: context,
    ),
  );
}

class _ArtistSheetBody extends StatefulWidget {
  final Artist artist;
  final BuildContext parentContext;

  const _ArtistSheetBody(
      {required this.artist, required this.parentContext});

  @override
  State<_ArtistSheetBody> createState() => _ArtistSheetBodyState();
}

class _ArtistSheetBodyState extends State<_ArtistSheetBody> {
  final _service = MusicService();
  final _player = MusicPlayerController();
  late Future<ArtistDetails?> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.artistDetails(widget.artist.id);
  }

  void _playList(List<Track> tracks, int index) {
    _player.playTracks(tracks, startIndex: index);
    Navigator.pop(context);
    Navigator.push(
      widget.parentContext,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  void _openAlbum(Album album) {
    Navigator.pop(context);
    showAlbumSheet(widget.parentContext, album);
  }

  void _openRelated(Artist artist) {
    Navigator.pop(context);
    showArtistSheet(widget.parentContext, artist);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FutureBuilder<ArtistDetails?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final details = snapshot.data;
              if (details == null) {
                return const Center(
                  child: Text('Artist unavailable right now.',
                      style: TextStyle(color: AppTheme.textDim)),
                );
              }
              return ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _header(details.artist.name, widget.artist.artwork,
                      'Artist'),
                  if (details.topTracks.isNotEmpty) ...[
                    const _SheetSection('Top tracks'),
                    for (var i = 0;
                        i < details.topTracks.length;
                        i++) ...[
                      TrackTile(
                        track: details.topTracks[i],
                        onTap: () =>
                            _playList(details.topTracks, i),
                      ),
                      if (i < details.topTracks.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                  if (details.albums.isNotEmpty) ...[
                    const _SheetSection('Albums'),
                    SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: details.albums.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (c, i) {
                          final a = details.albums[i];
                          return Pressable(
                            onTap: () => _openAlbum(a),
                            child: SizedBox(
                              width: 118,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 118,
                                    height: 118,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      color: AppTheme.surface,
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: a.artwork.isEmpty
                                          ? const Center(
                                              child: Icon(
                                                  Icons.album_rounded,
                                                  color: AppTheme
                                                      .textDim,
                                                  size: 28),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: a.artwork,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 240,
                                              fadeInDuration:
                                                  AppTheme.fast,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(a.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.text)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (details.related.isNotEmpty) ...[
                    const _SheetSection('Related artists'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: details.related
                          .map((a) => Pressable(
                                onTap: () => _openRelated(a),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.07),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppTheme.stroke),
                                  ),
                                  child: Text(a.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.text)),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(String title, String artwork, String kind) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface,
          ),
          child: ClipOval(
            child: artwork.isEmpty
                ? const Center(
                    child: Icon(Icons.person_rounded,
                        color: AppTheme.textDim, size: 30),
                  )
                : CachedNetworkImage(
                    imageUrl: artwork,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    fadeInDuration: AppTheme.fast,
                  ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text)),
              Text(kind,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textDim)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.textDim, size: 20),
            tooltip: 'Close',
          ),
        ),
      ],
    );
  }
}

/// Album details: full playable tracklist.
Future<void> showAlbumSheet(BuildContext context, Album album) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _AlbumSheetBody(
      album: album,
      parentContext: context,
    ),
  );
}

class _AlbumSheetBody extends StatefulWidget {
  final Album album;
  final BuildContext parentContext;

  const _AlbumSheetBody(
      {required this.album, required this.parentContext});

  @override
  State<_AlbumSheetBody> createState() => _AlbumSheetBodyState();
}

class _AlbumSheetBodyState extends State<_AlbumSheetBody> {
  late Future<AlbumDetails?> _future;
  final _player = MusicPlayerController();

  @override
  void initState() {
    super.initState();
    _future = MusicService().albumDetails(widget.album.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FutureBuilder<AlbumDetails?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              final details = snapshot.data;
              if (details == null || details.tracks.isEmpty) {
                return const Center(
                  child: Text('Album unavailable right now.',
                      style: TextStyle(color: AppTheme.textDim)),
                );
              }
              final tracks = details.tracks;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppTheme.surface,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: details.album.artwork.isEmpty
                              ? const Center(
                                  child: Icon(Icons.album_rounded,
                                      color: AppTheme.textDim,
                                      size: 30),
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      details.album.artwork,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 160,
                                  fadeInDuration: AppTheme.fast,
                                ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(details.album.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.text)),
                            Text(
                                '${tracks.length} tracks${details.album.artist.isNotEmpty ? ' • ${details.album.artist}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: AppTheme.textDim, size: 20),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (c, i) => TrackTile(
                        track: tracks[i],
                        onTap: () {
                          _player.playTracks(tracks, startIndex: i);
                          Navigator.pop(context);
                          Navigator.push(
                            widget.parentContext,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MusicPlayerScreen()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Curated provider playlist: full playable tracklist, read-only.
Future<void> showRemotePlaylistSheet(
    BuildContext context, RemotePlaylist playlist) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _RemotePlaylistSheetBody(
      playlist: playlist,
      parentContext: context,
    ),
  );
}

class _RemotePlaylistSheetBody extends StatefulWidget {
  final RemotePlaylist playlist;
  final BuildContext parentContext;

  const _RemotePlaylistSheetBody(
      {required this.playlist, required this.parentContext});

  @override
  State<_RemotePlaylistSheetBody> createState() =>
      _RemotePlaylistSheetBodyState();
}

class _RemotePlaylistSheetBodyState
    extends State<_RemotePlaylistSheetBody> {
  late Future<RemotePlaylistDetails?> _future;
  final _player = MusicPlayerController();

  @override
  void initState() {
    super.initState();
    _future = MusicService().playlistDetails(widget.playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FutureBuilder<RemotePlaylistDetails?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              final details = snapshot.data;
              if (details == null || details.tracks.isEmpty) {
                return const Center(
                  child: Text('Playlist unavailable right now.',
                      style: TextStyle(color: AppTheme.textDim)),
                );
              }
              final tracks = details.tracks;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(details.playlist.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.text)),
                            Text(
                                '${tracks.length} tracks • ${widget.playlist.source == 'deezer' ? 'Deezer' : 'Playlist'}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: AppTheme.textDim, size: 20),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (c, i) => TrackTile(
                        track: tracks[i],
                        onTap: () {
                          _player.playTracks(tracks, startIndex: i);
                          Navigator.pop(context);
                          Navigator.push(
                            widget.parentContext,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MusicPlayerScreen()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  const _SheetSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.text)),
    );
  }
}
