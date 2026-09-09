import '../models/music_models.dart';
import 'music_provider.dart';

/// Combined music search result, grouped the way the UI renders it.
class MusicSearchResult {
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;

  const MusicSearchResult({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && albums.isEmpty;
}

/// Aggregate facade over all [MusicProvider] backends. Runs providers
/// concurrently, isolates failures (one dead API never kills search),
/// and dedupes tracks across sources.
class MusicService {
  final List<MusicProvider> providers;

  MusicService({List<MusicProvider>? providers})
      : providers = providers ??
            [DeezerMusicProvider(), ItunesMusicProvider()];

  Future<MusicSearchResult> searchAll(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const MusicSearchResult();
    final trackJobs = <Future<List<Track>>>[];
    final artistJobs = <Future<List<Artist>>>[];
    final albumJobs = <Future<List<Album>>>[];
    for (final p in providers) {
      trackJobs.add(p.searchTracks(q).catchError((_) => <Track>[]));
      artistJobs.add(p.searchArtists(q).catchError((_) => <Artist>[]));
      albumJobs.add(p.searchAlbums(q).catchError((_) => <Album>[]));
    }
    final trackLists = await Future.wait(trackJobs);
    final artistLists = await Future.wait(artistJobs);
    final albumLists = await Future.wait(albumJobs);

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
    return MusicSearchResult(
        tracks: tracks, artists: artists, albums: albums);
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
}
