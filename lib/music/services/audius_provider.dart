import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import 'music_provider.dart';

/// Audius: free, legal, full-length streams, no API key.
/// Every read carries `app_name`; every stream is resolved per-play
/// (never stored) because playback URLs expire.
class AudiusMusicProvider implements MusicProvider {
  static const String _appName = 'Movix';
  static const String _selector = 'https://discoveryprovider.audius.co';
  static const String _nodeKey = 'audius_node';

  @override
  String get name => 'Audius';

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final decoded = json.decode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _dataList(Uri uri) async {
    final data = await _get(uri);
    final list = data?['data'];
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Track? _trackOf(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    final title = j['title']?.toString() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final user = j['user'] is Map
        ? Map<String, dynamic>.from(j['user'] as Map)
        : null;
    final art = j['artwork'] is Map
        ? Map<String, dynamic>.from(j['artwork'] as Map)
        : null;
    final durSec = (j['duration'] as num?)?.toInt() ?? 0;
    return Track(
      id: 'audius:$id',
      title: title,
      artist: user?['name']?.toString() ??
          user?['handle']?.toString() ??
          'Unknown artist',
      artistId: user != null ? 'audius:${user['id']}' : '',
      artworkSmall: art?['480x480']?.toString() ??
          art?['150x150']?.toString() ??
          '',
      artworkLarge: art?['1000x1000']?.toString() ??
          art?['480x480']?.toString() ??
          '',
      durationMs: durSec * 1000,
      source: 'audius',
      audioUrl: '',
      quality: 'Full track',
      explicit: false,
    );
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return [];
    final node = await AudiusDiscovery.endpoint();
    if (node.isEmpty) return [];
    final uri = Uri.parse('$node/v1/tracks/search').replace(
        queryParameters: {
          'query': query.trim(),
          'app_name': _appName,
          'limit': '$limit',
        });
    return (await _dataList(uri)).map(_trackOf).whereType<Track>().toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    // Audius has no artist-search endpoint; artist discovery flows
    // through track results and user top tracks instead.
    return [];
  }

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    return [];
  }

  @override
  Future<List<RemotePlaylist>> searchPlaylists(String query,
      {int limit = 10}) async {
    return [];
  }

  @override
  Future<Track?> lookupTrack(Track track) async {
    final remoteId = track.id.split(':').last;
    if (remoteId.isEmpty) return null;
    final node = await AudiusDiscovery.endpoint();
    if (node.isEmpty) return null;
    final data = await _get(Uri.parse('$node/v1/tracks/$remoteId')
        .replace(queryParameters: {'app_name': _appName}));
    if (data == null) return null;
    final obj = data['data'];
    if (obj is Map<String, dynamic>) return _trackOf(obj);
    return _trackOf(data);
  }

  @override
  Future<List<Track>> chartTracks({int limit = 20}) {
    return trendingTracks(limit: limit);
  }

  Future<List<Track>> trendingTracks({int limit = 20}) async {
    final node = await AudiusDiscovery.endpoint();
    if (node.isEmpty) return [];
    final uri = Uri.parse('$node/v1/tracks/trending').replace(
        queryParameters: {'app_name': _appName, 'limit': '$limit'});
    return (await _dataList(uri)).map(_trackOf).whereType<Track>().toList();
  }

  @override
  Future<ArtistDetails?> getArtistDetails(String artistId) async {
    final remoteId = artistId.split(':').last;
    if (remoteId.isEmpty || !artistId.startsWith('audius:')) return null;
    final node = await AudiusDiscovery.endpoint();
    if (node.isEmpty) return null;
    try {
      final data = await _get(Uri.parse('$node/v1/users/$remoteId')
          .replace(queryParameters: {'app_name': _appName}));
      if (data == null) return null;
      final obj =
          data['data'] is Map<String, dynamic> ? data['data'] : data;
      if (obj is! Map<String, dynamic>) return null;
      final pic = obj['profile_picture'] is Map
          ? Map<String, dynamic>.from(obj['profile_picture'] as Map)
          : null;
      final artist = Artist(
        id: 'audius:${obj['id']}',
        name: obj['name']?.toString() ??
            obj['handle']?.toString() ??
            'Unknown artist',
        artwork: pic?['480x480']?.toString() ??
            pic?['150x150']?.toString() ??
            '',
        source: 'audius',
      );
      final top = await _dataList(
          Uri.parse('$node/v1/users/$remoteId/tracks').replace(
              queryParameters: {
            'app_name': _appName,
            'sort': 'plays',
            'limit': '10',
          }));
      return ArtistDetails(
        artist: artist,
        topTracks:
            top.map(_trackOf).whereType<Track>().toList(),
      );
    } catch (_) {
      return null;
    }
  }

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

/// Discovery-node selection with memory: fresh selection first,
/// last-good node persisted as fallback. Verified live shape:
/// `{"data": ["https://<node>"], ...}` (plus plain-URL tolerance).
class AudiusDiscovery {
  static String? _cached;

  static Future<String> endpoint() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    try {
      final res = await http
          .get(Uri.parse('https://discoveryprovider.audius.co'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final node = _parseNode(res.body);
        if (node != null) {
          _cached = node;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('audius_node', node);
          } catch (_) {}
          return node;
        }
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('audius_node');
      if (saved != null && saved.startsWith('http')) {
        _cached = saved;
        return saved;
      }
    } catch (_) {}
    return 'https://api.audius.co';
  }

  static String? _parseNode(String body) {
    final t = body.trim();
    if (t.startsWith('http')) {
      return t
          .split(RegExp(r'\s'))
          .firstWhere((s) => s.startsWith('http'), orElse: () => '')
          .replaceAll(RegExp(r'[/"]+$'), '');
    }
    try {
      final decoded = json.decode(t);
      final found = _scan(decoded, 0);
      if (found != null) return found;
    } catch (_) {}
    return null;
  }

  static String? _scan(dynamic node, int depth) {
    if (depth > 4 || node == null) return null;
    if (node is String && node.startsWith('http')) {
      return node.replaceAll(RegExp(r'/+$'), '');
    }
    if (node is List) {
      for (final e in node) {
        final hit = _scan(e, depth + 1);
        if (hit != null) return hit;
      }
    }
    if (node is Map) {
      for (final key in ['data', 'endpoint', 'host', 'url']) {
        if (node.containsKey(key)) {
          final hit = _scan(node[key], depth + 1);
          if (hit != null) return hit;
        }
      }
    }
    return null;
  }
}
