import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

/// Eclipse/Qobuz lossless metadata + stream resolution, ported from
/// PlayTorrio's `QobuzMusicService`. Only the model type changed
/// (`MusicTrack` -> Nebula [Track]); endpoints, token flow, scoring
/// and caching are kept 1:1.
class QobuzTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? isrc;
  final String? audioQuality;
  final String? artworkUrl;
  final String? format;

  const QobuzTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.isrc,
    this.audioQuality,
    this.artworkUrl,
    this.format,
  });

  factory QobuzTrack.fromJson(Map<String, dynamic> json) {
    return QobuzTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Track',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString() ?? 'Single',
      durationSeconds: int.tryParse(json['duration']?.toString() ?? '') ?? 0,
      isrc: json['isrc']?.toString(),
      audioQuality:
          json['audioQuality']?.toString() ?? json['quality']?.toString(),
      artworkUrl:
          json['artworkURL']?.toString() ?? json['artworkUrl']?.toString(),
      format: json['format']?.toString() ?? 'flac',
    );
  }
}

class LosslessAudioService {
  static final LosslessAudioService instance = LosslessAudioService._internal();
  LosslessAudioService._internal();

  static const String defaultEndpoint =
      'https://qobuz-tidal-eclipse.cyrusna29.workers.dev/u/4opn823jmxs6yee60au24sse15kp';

  static const String generateUrl =
      'https://qobuz-tidal-eclipse.cyrusna29.workers.dev/generate';

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36';

  static const _storageEndpointKey = 'qobuz_eclipse_endpoint';
  static const _storageTokenKey = 'qobuz_eclipse_token';
  static const _storageManifestKey = 'qobuz_eclipse_manifest_url';

  String? _activeEndpoint;
  String? _token;
  String? _manifestUrl;
  String? _quality;

  String get activeEndpoint => _activeEndpoint ?? defaultEndpoint;
  String? get currentToken => _token;
  String? get currentManifestUrl => _manifestUrl;
  String? get currentQuality => _quality;

  final Map<String,
      ({String url, Map<String, String> headers, String quality, String format})>
      _cache = {};

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeEndpoint = prefs.getString(_storageEndpointKey);
      _token = prefs.getString(_storageTokenKey);
      _manifestUrl = prefs.getString(_storageManifestKey);
    } catch (_) {}
    await refreshEndpoint();
  }

  Future<bool> refreshEndpoint() async {
    try {
      debugPrint('[LosslessAudio] Generating fresh FLAC session...');
      final uri = Uri.parse(generateUrl);
      final headers = {
        'Content-Type': 'application/json',
        'Origin': 'https://qobuz-tidal-eclipse.cyrusna29.workers.dev',
        'Referer': 'https://qobuz-tidal-eclipse.cyrusna29.workers.dev/',
        'User-Agent': userAgent,
        'Accept': '*/*',
      };

      final response = await http
          .post(uri, headers: headers, body: '{}')
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token']?.toString();
        final quality = data['quality']?.toString();
        final manifestUrl = data['manifestUrl']?.toString();

        if (manifestUrl != null && manifestUrl.isNotEmpty) {
          _manifestUrl = manifestUrl;
          _token = token;
          _quality = quality;
          _activeEndpoint = manifestUrl.replaceAll('/manifest.json', '');

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_storageEndpointKey, _activeEndpoint!);
            if (_token != null) {
              await prefs.setString(_storageTokenKey, _token!);
            }
            await prefs.setString(_storageManifestKey, _manifestUrl!);
          } catch (_) {}

          return true;
        }
      } else {
        debugPrint(
            '[LosslessAudio] Generate returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LosslessAudio] Failed to generate endpoint: $e');
    }
    return false;
  }

  Future<List<QobuzTrack>> searchTracks(String query,
      {String? endpoint}) async {
    if (query.trim().isEmpty) return [];
    final base = endpoint ?? activeEndpoint;

    try {
      final url =
          Uri.parse('$base/search?q=${Uri.encodeComponent(query.trim())}');
      final res = await http.get(url, headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['tracks'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(QobuzTrack.fromJson)
                .where((t) => t.id.isNotEmpty)
                .toList() ??
            [];
      } else {
        debugPrint('[LosslessAudio] search HTTP ${res.statusCode} "$query"');
      }
    } catch (e) {
      debugPrint('[LosslessAudio] search failed "$query": $e');
    }
    return [];
  }

  Future<({String url, String format, String quality})?> getAudioStream(
    String trackId, {
    String? endpoint,
  }) async {
    final base = endpoint ?? activeEndpoint;
    try {
      final url = Uri.parse('$base/stream/$trackId');
      final res = await http.get(url, headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final streamUrl = data['url']?.toString();
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return (
            url: streamUrl,
            format: data['format']?.toString() ?? 'flac',
            quality: data['quality']?.toString() ?? 'FLAC Hi-Res',
          );
        }
      }
    } catch (e) {
      debugPrint('[LosslessAudio] stream failed $trackId: $e');
    }
    return null;
  }

  /// Matches a Nebula [Track] against Qobuz and returns the FLAC URL.
  Future<
      ({
        String url,
        Map<String, String> headers,
        String quality,
        String format
      })?> resolveLosslessUrl(Track track, {String? endpoint}) async {
    if (_cache.containsKey(track.id)) return _cache[track.id];

    try {
      final query = '${track.title} ${track.artist}'.trim();
      debugPrint('[LosslessAudio] Resolving "$query"...');
      var results = await searchTracks(query, endpoint: endpoint);

      if (results.isEmpty) {
        final cleanTitle = _cleanTitle(track.title);
        if (cleanTitle != track.title) {
          results = await searchTracks('$cleanTitle ${track.artist}'.trim(),
              endpoint: endpoint);
        }
      }

      if (results.isEmpty) return null;

      final matched = _pickBestMatch(track, results);
      if (matched == null) return null;

      final stream = await getAudioStream(matched.id, endpoint: endpoint);
      if (stream != null && stream.url.isNotEmpty) {
        final result = (
          url: stream.url,
          headers: <String, String>{'User-Agent': userAgent},
          quality: stream.quality,
          format: stream.format,
        );
        _cache[track.id] = result;
        return result;
      }
    } catch (e) {
      debugPrint('[LosslessAudio] resolve error ${track.title}: $e');
    }
    return null;
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\(feat\.[^)]+\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(ft\.[^)]+\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[feat\.[^\]]+\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[ft\.[^\]]+\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Radio Edit\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Remastered[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Remastered[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  QobuzTrack? _pickBestMatch(Track track, List<QobuzTrack> candidates) {
    if (candidates.isEmpty) return null;

    final normTitle = _normalize(track.title);
    final normArtist = _normalize(track.artist);
    final trackDuration =
        track.durationMs > 0 ? (track.durationMs ~/ 1000) : 0;

    QobuzTrack? best;
    var bestScore = -1;

    for (final c in candidates) {
      var score = 0;
      final cTitle = _normalize(c.title);
      final cArtist = _normalize(c.artist);

      if (cTitle == normTitle) {
        score += 50;
      } else if (cTitle.contains(normTitle) || normTitle.contains(cTitle)) {
        score += 35;
      }

      if (normArtist.isNotEmpty) {
        if (cArtist == normArtist) {
          score += 40;
        } else if (cArtist.contains(normArtist) ||
            normArtist.contains(cArtist)) {
          score += 25;
        }
      } else {
        score += 20;
      }

      if (trackDuration > 0 && c.durationSeconds > 0) {
        final diff = (trackDuration - c.durationSeconds).abs();
        if (diff <= 2) {
          score += 20;
        } else if (diff <= 5) {
          score += 10;
        } else if (diff <= 10) {
          score += 5;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    return best ?? candidates.first;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
