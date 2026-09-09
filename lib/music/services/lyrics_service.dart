import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';

/// Synced-lyrics backend, ported from PlayTorrio's `LyricsService`
/// (LRCLIB `get` + `search` with title cleaning and LRC parsing).
/// Adapted to Nebula's [Track] model; the wire protocol is unchanged.
class LyricsService {
  static final LyricsService instance = LyricsService._internal();
  LyricsService._internal();

  final Map<String, LyricsData> _cache = {};

  Future<LyricsData> getLyrics(Track track) async {
    if (_cache.containsKey(track.id)) return _cache[track.id]!;

    try {
      final cleanTitle = _clean(track.title);
      final cleanArtist = _clean(track.artist);
      final durationSecs =
          track.durationMs > 0 ? (track.durationMs ~/ 1000) : null;

      // 1. Exact match with album + duration.
      LyricsData? result = await _fetchLrcLib(
        track.id,
        track.title,
        track.artist,
        track.album.isNotEmpty ? track.album : null,
        durationSecs,
      );

      // 2. Relaxed match without album/duration.
      result ??= await _fetchLrcLib(
        track.id,
        cleanTitle,
        cleanArtist,
        null,
        null,
      );

      // 3. Free-text search fallback.
      result ??= await _searchLrcLib(track.id, '$cleanArtist $cleanTitle');

      if (result != null) {
        _cache[track.id] = result;
        return result;
      }
    } catch (e) {
      debugPrint('LyricsService error: $e');
    }

    const empty = LyricsData.empty();
    _cache[track.id] = empty;
    return empty;
  }

  Future<LyricsData?> _fetchLrcLib(
    String trackId,
    String title,
    String artist,
    String? album,
    int? duration,
  ) async {
    try {
      final query = <String, String>{
        'artist_name': artist,
        'track_name': title,
      };
      if (album != null && album.isNotEmpty && album != 'Single') {
        query['album_name'] = album;
      }
      if (duration != null && duration > 0) {
        query['duration'] = duration.toString();
      }

      final uri = Uri.https('lrclib.net', '/api/get', query);
      final res = await http.get(uri, headers: {
        'User-Agent': 'Movix/1.1.0',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        final plain = data['plainLyrics'] as String?;

        if (synced != null && synced.trim().isNotEmpty) {
          return LyricsData(
            trackId: trackId,
            isSynced: true,
            plainLyrics: plain ?? synced,
            syncedLines: parseLrc(synced),
          );
        } else if (plain != null && plain.trim().isNotEmpty) {
          return LyricsData(
            trackId: trackId,
            isSynced: false,
            plainLyrics: plain,
            syncedLines: const [],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LyricsData?> _searchLrcLib(String trackId, String query) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
      final res = await http.get(uri, headers: {
        'User-Agent': 'Movix/1.1.0',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final best = list.first as Map<String, dynamic>;
          final synced = best['syncedLyrics'] as String?;
          final plain = best['plainLyrics'] as String?;

          if (synced != null && synced.trim().isNotEmpty) {
            return LyricsData(
              trackId: trackId,
              isSynced: true,
              plainLyrics: plain ?? synced,
              syncedLines: parseLrc(synced),
            );
          } else if (plain != null && plain.trim().isNotEmpty) {
            return LyricsData(
              trackId: trackId,
              isSynced: false,
              plainLyrics: plain,
              syncedLines: const [],
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static List<SyncedLyricLine> parseLrc(String lrcContent) {
    final lines = <SyncedLyricLine>[];
    final regExp = RegExp(r'^\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)$');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final rawMillis = match.group(3) ?? '00';
        final millis = rawMillis.length == 2
            ? int.parse(rawMillis) * 10
            : int.parse(rawMillis);

        final text = match.group(4)?.trim() ?? '';
        lines.add(
          SyncedLyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  String _clean(String input) {
    return input
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'- .*'), '')
        .replaceAll(RegExp(r'feat\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\..*', caseSensitive: false), '')
        .trim();
  }
}
