import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';

/// One music backend. All provider specifics (URLs, JSON shapes) stay
/// behind this interface; the app only sees [Track]/[Artist]/[Album].
/// New sources are added by implementing this class — never by
/// touching the player or UI.
abstract class MusicProvider {
  String get name;

  Future<List<Track>> searchTracks(String query, {int limit = 25});
  Future<List<Artist>> searchArtists(String query, {int limit = 10});
  Future<List<Album>> searchAlbums(String query, {int limit = 10});
  Future<List<RemotePlaylist>> searchPlaylists(String query,
      {int limit = 10});

  /// Fresh metadata for one track (used to refresh expiring audio URLs).
  /// Returns null when the track is gone/unavailable.
  Future<Track?> lookupTrack(Track track);

  /// Browseable chart tracks for the music home screen.
  Future<List<Track>> chartTracks({int limit = 20});

  /// Full detail objects (null when unsupported/unavailable).
  Future<ArtistDetails?> getArtistDetails(String artistId);
  Future<AlbumDetails?> getAlbumDetails(String albumId);
  Future<RemotePlaylistDetails?> getPlaylistDetails(String playlistId);

  /// Genre directory + curated rows.
  Future<List<MusicGenre>> getGenres();
  Future<List<RemotePlaylist>> chartPlaylists({int limit = 10});
  Future<List<Album>> newReleases({int limit = 10});
}

Future<Map<String, dynamic>?> _getJson(Uri uri) async {
  return DeezerHttp.getJson(uri);
}

/// Deezer HTTP layer with PlayTorrio's geo-restriction proxy fallback:
/// probes the API once, then retries failed calls through a CORS proxy.
class DeezerHttp {
  static const _proxyPrefix =
      'https://wave-proxy.aymanisthedude1.workers.dev/proxy?url=';
  static bool useProxy = false;
  static bool _geoChecked = false;

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
  };

  static Future<void> _checkGeo() async {
    if (_geoChecked) return;
    _geoChecked = true;
    try {
      final res = await http
          .get(Uri.parse('https://api.deezer.com/search?q=believer'),
              headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) {
        useProxy = true;
        return;
      }
      final data = json.decode(res.body);
      if (data is Map &&
          (data['error'] != null ||
              (data['data'] is List && (data['data'] as List).isEmpty))) {
        useProxy = true;
      } else {
        useProxy = false;
      }
    } catch (_) {
      useProxy = true;
    }
  }

  static Future<Map<String, dynamic>?> getJson(Uri uri) async {
    await _checkGeo();
    final direct = await _fetch(uri, proxied: false);
    if (direct != null) return direct;
    if (!useProxy) {
      useProxy = true;
      return _fetch(uri, proxied: true);
    }
    return _fetch(uri, proxied: true);
  }

  static Future<Map<String, dynamic>?> _fetch(Uri uri,
      {required bool proxied}) async {
    try {
      final target = proxied
          ? Uri.parse('$_proxyPrefix${Uri.encodeComponent(uri.toString())}')
          : uri;
      final res = await http
          .get(target, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = json.decode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

int _asMs(dynamic seconds, dynamic millis) {
  if (millis is num) return millis.toInt();
  if (seconds is num) return (seconds * 1000).toInt();
  return 0;
}

/// iTunes Search API — free, no key. 30s preview streams served
/// explicitly for preview playback.
class ItunesMusicProvider implements MusicProvider {
  @override
  String get name => 'iTunes';

  Uri _searchUri(String entity, String query, int limit) =>
      Uri.parse('https://itunes.apple.com/search').replace(
        queryParameters: {
          'term': query,
          'media': 'music',
          'entity': entity,
          'limit': '$limit',
        },
      );

  Track? _trackOf(Map<String, dynamic> j) {
    final preview = j['previewUrl']?.toString() ?? '';
    final title = j['trackName']?.toString() ?? '';
    if (title.isEmpty) return null;
    final art100 = j['artworkUrl100']?.toString() ?? '';
    return Track(
      id: 'itunes:${j['trackId']}',
      title: title,
      artist: j['artistName']?.toString() ?? 'Unknown artist',
      artistId: '${j['artistId'] ?? ''}',
      album: j['collectionName']?.toString() ?? '',
      albumId: '${j['collectionId'] ?? ''}',
      artworkSmall: art100,
      artworkLarge: art100.replaceAll('100x100', '600x600'),
      durationMs: _asMs(null, j['trackTimeMillis']),
      source: 'itunes',
      audioUrl: preview,
      quality: 'Preview',
      explicit:
          (j['trackExplicitness']?.toString() ?? '') != 'notExplicit',
    );
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    final data = await _getJson(_searchUri('song', query, limit));
    final results = data?['results'];
    if (results is! List) return [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(_trackOf)
        .whereType<Track>()
        .where((t) => t.audioUrl.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    final data = await _getJson(_searchUri('musicArtist', query, limit));
    final results = data?['results'];
    if (results is! List) return [];
    return results.whereType<Map<String, dynamic>>().map((j) {
      return Artist(
        id: 'itunes:${j['artistId']}',
        name: j['artistName']?.toString() ?? 'Unknown artist',
        source: 'itunes',
      );
    }).where((a) => a.name != 'Unknown artist').toList();
  }

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final data = await _getJson(_searchUri('album', query, limit));
    final results = data?['results'];
    if (results is! List) return [];
    return results.whereType<Map<String, dynamic>>().map((j) {
      final art100 = j['artworkUrl100']?.toString() ?? '';
      return Album(
        id: 'itunes:${j['collectionId']}',
        title: j['collectionName']?.toString() ?? 'Unknown album',
        artist: j['artistName']?.toString() ?? '',
        artwork: art100.replaceAll('100x100', '600x600'),
        source: 'itunes',
      );
    }).where((a) => a.title != 'Unknown album').toList();
  }

  @override
  Future<Track?> lookupTrack(Track track) async {
    final remoteId = track.id.split(':').last;
    if (remoteId.isEmpty) return null;
    final data = await _getJson(Uri.parse(
        'https://itunes.apple.com/lookup?id=$remoteId&entity=song'));
    final results = data?['results'];
    if (results is! List) return null;
    for (final j in results.whereType<Map<String, dynamic>>()) {
      final t = _trackOf(j);
      if (t != null && t.audioUrl.isNotEmpty) return t;
    }
    return null;
  }

  @override
  Future<List<Track>> chartTracks({int limit = 20}) async {
    // No keyless chart endpoint with previews; a top-hits search doubles
    // as browse content and always returns playable previews.
    return searchTracks('top hits 2026', limit: limit);
  }

  // iTunes exposes no playlist directory or detail endpoints without
  // authentication; the interface stays uniform, these stay empty.
  @override
  Future<List<RemotePlaylist>> searchPlaylists(String query,
      {int limit = 10}) async {
    return [];
  }

  @override
  Future<ArtistDetails?> getArtistDetails(String artistId) async => null;

  @override
  Future<AlbumDetails?> getAlbumDetails(String albumId) async => null;

  @override
  Future<RemotePlaylistDetails?> getPlaylistDetails(String playlistId) async =>
      null;

  @override
  Future<List<MusicGenre>> getGenres() async => [];

  @override
  Future<List<RemotePlaylist>> chartPlaylists({int limit = 10}) async => [];

  @override
  Future<List<Album>> newReleases({int limit = 10}) async => [];
}

/// Deezer public API — free, no key. 30s preview streams plus charts
/// and per-artist top tracks.
class DeezerMusicProvider implements MusicProvider {
  @override
  String get name => 'Deezer';

  Track? _trackOf(Map<String, dynamic> j) {
    final preview = j['preview']?.toString() ?? '';
    final title = j['title']?.toString() ?? '';
    if (title.isEmpty || preview.isEmpty) return null;
    final artist = j['artist'];
    final album = j['album'];
    final artistMap = artist is Map<String, dynamic> ? artist : null;
    final albumMap = album is Map<String, dynamic> ? album : null;
    return Track(
      id: 'deezer:${j['id']}',
      title: title,
      artist: artistMap?['name']?.toString() ?? 'Unknown artist',
      artistId: '${artistMap?['id'] ?? ''}',
      album: albumMap?['title']?.toString() ?? '',
      albumId: '${albumMap?['id'] ?? ''}',
      artworkSmall:
          albumMap?['cover_small']?.toString() ?? '',
      artworkLarge: albumMap?['cover_big']?.toString() ??
          albumMap?['cover_medium']?.toString() ??
          '',
      durationMs: _asMs(j['duration'], null),
      source: 'deezer',
      audioUrl: preview,
      quality: 'Preview',
      explicit: j['explicit_lyrics'] == true,
    );
  }

  Future<List<Map<String, dynamic>>> _dataList(Uri uri) async {
    final data = await _getJson(uri);
    final list = data?['data'];
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    final uri = Uri.parse('https://api.deezer.com/search')
        .replace(queryParameters: {'q': query, 'limit': '$limit'});
    return (await _dataList(uri))
        .map(_trackOf)
        .whereType<Track>()
        .toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    final uri = Uri.parse('https://api.deezer.com/search/artist')
        .replace(queryParameters: {'q': query, 'limit': '$limit'});
    return (await _dataList(uri)).map((j) {
      return Artist(
        id: 'deezer:${j['id']}',
        name: j['name']?.toString() ?? 'Unknown artist',
        artwork: j['picture_medium']?.toString() ?? '',
        source: 'deezer',
      );
    }).where((a) => a.name != 'Unknown artist').toList();
  }

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final uri = Uri.parse('https://api.deezer.com/search/album')
        .replace(queryParameters: {'q': query, 'limit': '$limit'});
    return (await _dataList(uri)).map((j) {
      final artist = j['artist'];
      return Album(
        id: 'deezer:${j['id']}',
        title: j['title']?.toString() ?? 'Unknown album',
        artist: artist is Map<String, dynamic>
            ? artist['name']?.toString() ?? ''
            : '',
        artwork: j['cover_medium']?.toString() ?? '',
        source: 'deezer',
      );
    }).where((a) => a.title != 'Unknown album').toList();
  }

  @override
  Future<Track?> lookupTrack(Track track) async {
    final remoteId = track.id.split(':').last;
    if (remoteId.isEmpty) return null;
    final data =
        await _getJson(Uri.parse('https://api.deezer.com/track/$remoteId'));
    if (data == null || data['error'] != null) return null;
    return _trackOf(data);
  }

  @override
  Future<List<Track>> chartTracks({int limit = 20}) async {
    final uri = Uri.parse('https://api.deezer.com/chart/0/tracks')
        .replace(queryParameters: {'limit': '$limit'});
    return (await _dataList(uri))
        .map(_trackOf)
        .whereType<Track>()
        .toList();
  }

  RemotePlaylist? _remotePlaylistOf(Map<String, dynamic> j) {
    final title = j['title']?.toString() ?? '';
    if (title.isEmpty) return null;
    return RemotePlaylist(
      id: 'deezer:${j['id']}',
      title: title,
      artwork: j['picture_medium']?.toString() ?? '',
      source: 'deezer',
      trackCount: (j['nb_tracks'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<RemotePlaylist>> searchPlaylists(String query,
      {int limit = 10}) async {
    final uri = Uri.parse('https://api.deezer.com/search/playlist')
        .replace(queryParameters: {'q': query, 'limit': '$limit'});
    return (await _dataList(uri))
        .map(_remotePlaylistOf)
        .whereType<RemotePlaylist>()
        .toList();
  }

  @override
  Future<ArtistDetails?> getArtistDetails(String artistId) async {
    final remoteId = artistId.split(':').last;
    if (remoteId.isEmpty) return null;
    try {
      final data =
          await _getJson(Uri.parse('https://api.deezer.com/artist/$remoteId'));
      if (data == null || data['id'] == null) return null;
      final artist = Artist(
        id: 'deezer:${data['id']}',
        name: data['name']?.toString() ?? 'Unknown artist',
        artwork: data['picture_medium']?.toString() ?? '',
        source: 'deezer',
      );
      final results = await Future.wait([
        _dataList(Uri.parse('https://api.deezer.com/artist/$remoteId/top')
            .replace(queryParameters: {'limit': '20'})),
        _dataList(Uri.parse('https://api.deezer.com/artist/$remoteId/albums')
            .replace(queryParameters: {'limit': '20'})),
        _dataList(Uri.parse('https://api.deezer.com/artist/$remoteId/related')
            .replace(queryParameters: {'limit': '10'})),
      ]);
      return ArtistDetails(
        artist: artist,
        topTracks: results[0].map(_trackOf).whereType<Track>().toList(),
        albums: results[1].map((j) {
          final art = j['cover_medium']?.toString() ?? '';
          return Album(
            id: 'deezer:${j['id']}',
            title: j['title']?.toString() ?? 'Unknown album',
            artist: artist.name,
            artwork: art,
            source: 'deezer',
          );
        }).where((a) => a.title != 'Unknown album').toList(),
        related: results[2].map((j) {
          return Artist(
            id: 'deezer:${j['id']}',
            name: j['name']?.toString() ?? 'Unknown artist',
            artwork: j['picture_medium']?.toString() ?? '',
            source: 'deezer',
          );
        }).where((a) => a.name != 'Unknown artist').toList(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AlbumDetails?> getAlbumDetails(String albumId) async {
    final remoteId = albumId.split(':').last;
    if (remoteId.isEmpty) return null;
    try {
      final data =
          await _getJson(Uri.parse('https://api.deezer.com/album/$remoteId'));
      if (data == null || data['id'] == null) return null;
      final album = Album(
        id: 'deezer:${data['id']}',
        title: data['title']?.toString() ?? 'Unknown album',
        artist: (data['artist'] is Map)
            ? (data['artist'] as Map)['name']?.toString() ?? ''
            : '',
        artwork: data['cover_big']?.toString() ??
            data['cover_medium']?.toString() ??
            '',
        source: 'deezer',
      );
      var rawTracks = <Map<String, dynamic>>[];
      final embedded = data['tracks'];
      if (embedded is Map && embedded['data'] is List) {
        rawTracks =
            (embedded['data'] as List).whereType<Map<String, dynamic>>().toList();
      } else {
        rawTracks = await _dataList(
            Uri.parse('https://api.deezer.com/album/$remoteId/tracks')
                .replace(queryParameters: {'limit': '100'}));
      }
      final tracks = rawTracks.map((j) {
        final withArt = Map<String, dynamic>.from(j);
        withArt['album'] ??= {
          'id': data['id'],
          'title': album.title,
          'cover_small': data['cover_small'],
          'cover_medium': data['cover_medium'],
          'cover_big': data['cover_big'],
        };
        return _trackOf(withArt);
      }).whereType<Track>().toList();
      return AlbumDetails(album: album, tracks: tracks);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RemotePlaylistDetails?> getPlaylistDetails(String playlistId) async {
    final remoteId = playlistId.split(':').last;
    if (remoteId.isEmpty) return null;
    try {
      final data = await _getJson(
          Uri.parse('https://api.deezer.com/playlist/$remoteId'));
      if (data == null || data['id'] == null) return null;
      final playlist = _remotePlaylistOf(data);
      if (playlist == null) return null;
      var rawTracks = <Map<String, dynamic>>[];
      final embedded = data['tracks'];
      if (embedded is Map && embedded['data'] is List) {
        rawTracks =
            (embedded['data'] as List).whereType<Map<String, dynamic>>().toList();
      } else {
        rawTracks = await _dataList(
            Uri.parse('https://api.deezer.com/playlist/$remoteId/tracks')
                .replace(queryParameters: {'limit': '100'}));
      }
      return RemotePlaylistDetails(
        playlist: playlist,
        tracks:
            rawTracks.map(_trackOf).whereType<Track>().toList(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MusicGenre>> getGenres() async {
    final data =
        await _getJson(Uri.parse('https://api.deezer.com/genre'));
    final list = data?['data'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => MusicGenre(
              id: '${j['id']}',
              name: j['name']?.toString() ?? '',
            ))
        .where((g) => g.id != '0' && g.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<RemotePlaylist>> chartPlaylists({int limit = 10}) async {
    final uri = Uri.parse('https://api.deezer.com/chart/0/playlists')
        .replace(queryParameters: {'limit': '$limit'});
    return (await _dataList(uri))
        .map(_remotePlaylistOf)
        .whereType<RemotePlaylist>()
        .toList();
  }

  @override
  Future<List<Album>> newReleases({int limit = 10}) async {
    final uri = Uri.parse('https://api.deezer.com/editorial/0/releases')
        .replace(queryParameters: {'limit': '$limit'});
    return (await _dataList(uri)).map((j) {
      final artist = j['artist'];
      return Album(
        id: 'deezer:${j['id']}',
        title: j['title']?.toString() ?? 'Unknown album',
        artist: artist is Map<String, dynamic>
            ? artist['name']?.toString() ?? ''
            : '',
        artwork: j['cover_medium']?.toString() ?? '',
        source: 'deezer',
      );
    }).where((a) => a.title != 'Unknown album').toList();
  }

  /// Top tracks of an artist — feeds recommendations.
  Future<List<Track>> artistTopTracks(String artistId,
      {int limit = 10}) async {
    final remoteId = artistId.split(':').last;
    if (remoteId.isEmpty) return [];
    final uri =
        Uri.parse('https://api.deezer.com/artist/$remoteId/top')
            .replace(queryParameters: {'limit': '$limit'});
    return (await _dataList(uri))
        .map(_trackOf)
        .whereType<Track>()
        .toList();
  }
}
