import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/music_models.dart';
import 'convertytmp3_client.dart';
import 'youtube_audio_extractor.dart';
import 'youtube_rate_limit_guard.dart';

/// YouTube HQ fallback chain, ported from PlayTorrio's
/// `YoutubeStreamResolver`: in-memory stream cache -> cached videoId ->
/// InnerTube extraction -> ConvertYTMP3 fallback -> provider preview.
class YoutubeStreamResolver {
  static final YoutubeStreamResolver instance =
      YoutubeStreamResolver._internal();
  YoutubeStreamResolver._internal();

  final Map<String, String> _cache = <String, String>{};
  final Map<String, ({String url, String userAgent})> _streamCache = {};

  Future<({String url, String? userAgent})?> resolveUrl(
    Track track, {
    bool verifyStream = false,
  }) async {
    YoutubeRateLimitGuard.throwIfLimited();

    if (_streamCache.containsKey(track.id)) {
      final cached = _streamCache[track.id]!;
      return (url: cached.url, userAgent: cached.userAgent);
    }

    final cachedVid = _cache[track.id];
    if (cachedVid != null) {
      try {
        final res = await YoutubeAudioExtractor.instance
            .getAudioUrl(cachedVid, verifyStream: verifyStream)
            .timeout(const Duration(seconds: 8), onTimeout: () => null);
        if (res != null) {
          _streamCache[track.id] = res;
          return (url: res.url, userAgent: res.userAgent);
        }
      } catch (_) {
        _cache.remove(track.id);
      }
    }

    try {
      final res = await YoutubeRateLimitGuard.runLowRequest(
        () => YoutubeAudioExtractor.instance
            .extract(
              track.title,
              track.artist,
              targetDuration: track.durationMs > 0
                  ? Duration(milliseconds: track.durationMs)
                  : null,
              verifyStream: verifyStream,
            )
            .timeout(const Duration(seconds: 12), onTimeout: () => null),
      );

      if (res != null) {
        _cache[track.id] = res.videoId;
        _streamCache[track.id] =
            (url: res.audioUrl, userAgent: res.userAgent);
        return (url: res.audioUrl, userAgent: res.userAgent);
      }
    } catch (e) {
      debugPrint('YoutubeAudioExtractor error for ${track.title}: $e');
    }

    final vidId = _cache[track.id];
    if (vidId != null) {
      try {
        final streamUrl = await Convertytmp3Client.getStreamUrl(vidId);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return (
            url: streamUrl,
            userAgent:
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
          );
        }
      } catch (e) {
        debugPrint('Convertytmp3 fallback error: $e');
      }
    }

    if (track.audioUrl.isNotEmpty) {
      debugPrint('Falling back to provider preview for ${track.title}');
      return (
        url: track.audioUrl,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      );
    }

    return null;
  }
}
