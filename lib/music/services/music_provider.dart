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

  /// Fresh metadata for one track (used to refresh expiring audio URLs).
  /// Returns null when the track is gone/unavailable.
  Future<Track?> lookupTrack(Track track);

  /// Browseable chart tracks for the music home screen.
  Future<List<Track>> chartTracks({int limit = 20});
}

Future<Map<String, dynamic>?> _getJson(Uri uri) async {
  try {
    final res =
        await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final decoded = json.decode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
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
