import '../models/music_models.dart';
import 'audius_provider.dart';
import 'lossless_audio_service.dart';
import 'lyrics_service.dart';
import 'music_provider.dart';
import 'music_settings.dart';
import 'youtube_stream_resolver.dart';

/// Combined music search result, grouped the way the UI renders it.
class MusicSearchResult {
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<RemotePlaylist> playlists;

  const MusicSearchResult({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty;
}

/// Aggregate facade over all [MusicProvider] backends. Runs providers
/// concurrently, isolates failures (one dead API never kills search),
/// and dedupes tracks across sources.
class MusicService {
  final List<MusicProvider> providers;

  /// Audius first: its tracks are full-length, so they surface
  /// at the top of merged results.
  MusicService({List<MusicProvider>? providers})
      : providers = providers ??
            [
              AudiusMusicProvider(),
              DeezerMusicProvider(),
              ItunesMusicProvider(),
            ];

  Future<MusicSearchResult> searchAll(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const MusicSearchResult();
    final trackJobs = <Future<List<Track>>>[];
    final artistJobs = <Future<List<Artist>>>[];
    final albumJobs = <Future<List<Album>>>[];
    final playlistJobs = <Future<List<RemotePlaylist>>>[];
    for (final p in providers) {
      trackJobs.add(p.searchTracks(q).catchError((_) => <Track>[]));
      artistJobs.add(p.searchArtists(q).catchError((_) => <Artist>[]));
      albumJobs.add(p.searchAlbums(q).catchError((_) => <Album>[]));
      playlistJobs
          .add(p.searchPlaylists(q).catchError((_) => <RemotePlaylist>[]));
    }
    final trackLists = await Future.wait(trackJobs);
    final artistLists = await Future.wait(artistJobs);
    final albumLists = await Future.wait(albumJobs);
    final playlistLists = await Future.wait(playlistJobs);

    final seenTracks = <String>{};
    final tracks = <Track>[];
    for (final list in trackLists) {
      for (final t in list) {
        if (seenTracks.add(t.id)) tracks.add(t);
      }
    }
    final seenArtists = <String>{};
    final artists = <Artist>[];
    for (final list in artistLists) {
      for (final a in list) {
        if (seenArtists.add(a.id)) artists.add(a);
        if (artists.length >= 12) break;
      }
    }
    final seenAlbums = <String>{};
    final albums = <Album>[];
    for (final list in albumLists) {
      for (final a in list) {
        if (seenAlbums.add(a.id)) albums.add(a);
        if (albums.length >= 12) break;
      }
    }
    final seenPlaylists = <String>{};
    final playlists = <RemotePlaylist>[];
    for (final list in playlistLists) {
      for (final p in list) {
        if (seenPlaylists.add(p.id)) playlists.add(p);
        if (playlists.length >= 8) break;
      }
    }
    return MusicSearchResult(
        tracks: tracks,
        artists: artists,
        albums: albums,
        playlists: playlists);
  }

  /// Browse rows for the music home screen (charts per provider).
  Future<Map<String, List<Track>>> browse() async {
    final out = <String, List<Track>>{};
    for (final p in providers) {
      try {
        final tracks = await p.chartTracks(limit: 15);
        if (tracks.isNotEmpty) out[p.name] = tracks;
      } catch (_) {}
    }
    return out;
  }

  /// Featured genre/mood rows, mirroring curated home sections:
  /// one named query per row, all resolved against the Deezer backend.
  Future<Map<String, List<Track>>> featuredSections() async {
    const queries = {
      'Pop Essentials': 'Top Pop Hits',
      'Hip-Hop Hits': 'Hip Hop Hits',
      'Rock Essentials': 'Rock Essentials',
      'Chill & Lofi': 'Lofi Beats Chill',
    };
    final deezer = _deezer();
    if (deezer == null) return {};
    final out = <String, List<Track>>{};
    final audius = _audius();
    if (audius != null) {
      try {
        final trending = await audius.trendingTracks(limit: 12);
        if (trending.isNotEmpty) out['Trending Now'] = trending;
      } catch (_) {}
    }
    final jobs = <Future<void>>[];
    for (final entry in queries.entries) {
      jobs.add(deezer
          .searchTracks(entry.value, limit: 12)
          .then((tracks) {
            if (tracks.isNotEmpty) out[entry.key] = tracks;
          })
          .catchError((_) {}));
    }
    await Future.wait(jobs);
    return out;
  }

  Future<List<MusicGenre>> genres() async {
    final deezer = _deezer();
    if (deezer == null) return [];
    try {
      return await deezer.getGenres();
    } catch (_) {
      return [];
    }
  }

  Future<List<RemotePlaylist>> chartPlaylists({int limit = 10}) async {
    final deezer = _deezer();
    if (deezer == null) return [];
    try {
      return await deezer.chartPlaylists(limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<ArtistDetails?> artistDetails(String artistId) async {
    for (final p in providers) {
      try {
        final details = await p.getArtistDetails(artistId);
        if (details != null) return details;
      } catch (_) {}
    }
    return null;
  }

  Future<AlbumDetails?> albumDetails(String albumId) async {
    for (final p in providers) {
      try {
        final details = await p.getAlbumDetails(albumId);
        if (details != null) return details;
      } catch (_) {}
    }
    return null;
  }

  Future<RemotePlaylistDetails?> playlistDetails(String playlistId) async {
    for (final p in providers) {
      try {
        final details = await p.getPlaylistDetails(playlistId);
        if (details != null) return details;
      } catch (_) {}
    }
    return null;
  }

  DeezerMusicProvider? _deezer() {
    for (final p in providers) {
      if (p is DeezerMusicProvider) return p;
    }
    return null;
  }

  AudiusMusicProvider? _audius() {
    for (final p in providers) {
      if (p is AudiusMusicProvider) return p;
    }
    return null;
  }

  /// Fresh metadata for a track (used before playback to survive
  /// expired/moved audio URLs). Tries the track's own provider first.
  Future<Track?> refreshTrack(Track track) async {
    final ordered = List<MusicProvider>.from(providers)
      ..sort((a, b) {
        final aOwn = a.name.toLowerCase() == track.source ? 0 : 1;
        final bOwn = b.name.toLowerCase() == track.source ? 0 : 1;
        return aOwn.compareTo(bOwn);
      });
    for (final p in ordered) {
      try {
        final fresh = await p.lookupTrack(track);
        if (fresh != null && fresh.audioUrl.isNotEmpty) return fresh;
      } catch (_) {}
    }
    return track.audioUrl.isNotEmpty ? track : null;
  }

  /// PlayTorrio-style stream pick: FLAC lossless first (or YouTube when
  /// the user prefers it), falling back across the other source.
  Future<MusicStreamResult?> getAudioStream(
    Track track, {
    MusicAudioSource source = MusicAudioSource.flac,
  }) async {
    if (source == MusicAudioSource.flac) {
      try {
        final flac =
            await LosslessAudioService.instance.resolveLosslessUrl(track);
        if (flac != null && flac.url.isNotEmpty) {
          return MusicStreamResult(
            url: flac.url,
            quality: flac.quality,
            format: flac.format,
            isLossless: true,
          );
        }
      } catch (_) {}
    }
    final yt = await YoutubeStreamResolver.instance.resolveUrl(track);
    if (yt != null && yt.url.isNotEmpty) {
      return MusicStreamResult(
        url: yt.url,
        quality: 'YouTube HQ',
        format: 'm4a',
        isLossless: false,
      );
    }
    if (track.audioUrl.isNotEmpty) {
      return MusicStreamResult(
          url: track.audioUrl,
          quality: track.quality,
          format: 'mp3',
          isLossless: false);
    }
    return null;
  }

  /// PlayTorrio-style synced/plain lyrics for the player sheet.
  Future<LyricsData> fetchLyrics(Track track) =>
      LyricsService.instance.getLyrics(track);

  /// PlayTorrio home rows: global chart + curated mood searches.
  Future<Map<String, List<Track>>> fetchFeaturedSections() async {
    const queries = {
      'Top Global & Trending Hits': null,
      'Pop Essentials': 'Top Pop Hits',
      'Hip-Hop & Rap Heavyweights': 'Hip Hop Hits',
      'Electronic, Dance & EDM': 'Electronic Dance',
      'Rock Classics & Alternative': 'Rock Essentials',
      'Chill, Lofi & Ambient Beats': 'Lofi Beats Chill',
    };
    final out = <String, List<Track>>{};
    final deezer = _deezer();
    if (deezer == null) return featuredSections();
    try {
      final chart = await deezer.chartTracks(limit: 25);
      if (chart.isNotEmpty) {
        out['Top Global & Trending Hits'] = chart;
      }
      for (final entry in queries.entries.skip(1)) {
        try {
          final tracks =
              await deezer.searchTracks(entry.value!, limit: 15);
          if (tracks.isNotEmpty) out[entry.key] = tracks;
        } catch (_) {}
      }
    } catch (_) {}
    if (out.isEmpty) return featuredSections();
    return out;
  }

  Future<List<Artist>> fetchTrendingArtists({int limit = 20}) async {
    final deezer = _deezer();
    if (deezer == null) return [];
    try {
      final details = await deezer.chartTracks(limit: limit);
      final seen = <String>{};
      final artists = <Artist>[];
      for (final t in details) {
        if (t.artistId.isEmpty || !seen.add(t.artistId)) continue;
        artists.add(Artist(
          id: 'deezer:${t.artistId}',
          name: t.artist,
          artwork: t.artworkSmall,
          source: 'deezer',
        ));
      }
      return artists;
    } catch (_) {
      return [];
    }
  }

  Future<List<Album>> fetchNewReleases({int limit = 20}) async {
    final deezer = _deezer();
    if (deezer == null) return [];
    try {
      return await deezer.newReleases(limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<RemotePlaylist>> fetchCuratedPlaylists({int limit = 20}) async {
    try {
      return await chartPlaylists(limit: limit);
    } catch (_) {
      return [];
    }
  }
}

/// Resolved playable stream with quality metadata for badges.
class MusicStreamResult {
  final String url;
  final String quality;
  final String format;
  final bool isLossless;

  const MusicStreamResult({
    required this.url,
    this.quality = 'Preview',
    this.format = 'mp3',
    this.isLossless = false,
  });
}
