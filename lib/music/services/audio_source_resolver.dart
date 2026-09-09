import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';
import 'audius_provider.dart';
import 'lossless_audio_service.dart';
import 'music_service.dart';
import 'music_download_service.dart';
import 'music_settings.dart';
import 'youtube_stream_http.dart';
import 'youtube_stream_resolver.dart';

/// UI-independent audio resolution: receives a [Track], returns a
/// playable [AudioSource]. Widgets never touch providers or URLs —
/// they hand a track to the player controller, which resolves it here.
///
/// Add new sources by implementing this interface (e.g. a licensed
/// full-track resolver); the player UI stays untouched.
abstract class AudioSourceResolver {
  Future<AudioSource> resolveTrack(Track track);
}

class AudioResolveException implements Exception {
  final String message;
  const AudioResolveException(this.message);

  @override
  String toString() => message;
}

/// Tries resolvers in priority order and returns the first playable
/// source. UI and player depend only on this — never on a concrete
/// provider. New sources slot in as another list entry.
class PrioritizedAudioResolver implements AudioSourceResolver {
  final List<AudioSourceResolver> resolvers;

  PrioritizedAudioResolver({required this.resolvers});

  @override
  Future<AudioSource> resolveTrack(Track track) async {
    Object? lastError;
    for (final r in resolvers) {
      try {
        final src = await r
            .resolveTrack(track)
            .timeout(const Duration(seconds: 20));
        if (src.url.isNotEmpty) return src;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError is AudioResolveException) throw lastError;
    throw const AudioResolveException('This track is unavailable right now.');
  }
}

/// Resolves full-length Audius streams. Handles only `audius:` tracks;
/// everything else falls through to the next resolver in the chain.
/// The expiring playback URL is unwrapped per play and never stored.
class AudiusAudioResolver implements AudioSourceResolver {
  static final _client = http.Client();

  @override
  Future<AudioSource> resolveTrack(Track track) async {
    if (!track.id.startsWith('audius:')) {
      throw const AudioResolveException('Not an Audius track.');
    }
    final remoteId = track.id.split(':').last;
    if (remoteId.isEmpty) {
      throw const AudioResolveException('This track is unavailable right now.');
    }
    final node = await AudiusDiscovery.endpoint();
    final streamUri =
        Uri.parse('$node/v1/tracks/$remoteId/stream').replace(
      queryParameters: {'app_name': 'Movix'},
    );
    // Unwrap the redirect to the final host when possible; the player
    // follows redirects too, so the plain endpoint is a safe fallback.
    try {
      final req = http.Request('HEAD', streamUri)..followRedirects = false;
      final resp =
          await _client.send(req).timeout(const Duration(seconds: 10));
      final loc = resp.headers['location'];
      if (loc != null && loc.isNotEmpty) {
        return AudioSource(url: loc, quality: 'Full track');
      }
    } catch (_) {}
    return AudioSource(url: streamUri.toString(), quality: 'Full track');
  }
}

/// Resolves preview streams via [MusicService.refreshTrack], so moved
/// or expired audio URLs are refreshed right before playback instead
/// of failing mid-queue.
class PreviewAudioResolver implements AudioSourceResolver {
  final MusicService service;

  PreviewAudioResolver({MusicService? service})
      : service = service ?? MusicService();

  @override
  Future<AudioSource> resolveTrack(Track track) async {
    if (track.audioUrl.isNotEmpty) {
      try {
        final fresh = await service
            .refreshTrack(track)
            .timeout(const Duration(seconds: 10));
        if (fresh != null && fresh.audioUrl.isNotEmpty) {
          return AudioSource(
              url: fresh.audioUrl, quality: fresh.quality);
        }
      } catch (_) {
        // Fall through to the embedded URL below.
      }
      return AudioSource(url: track.audioUrl, quality: track.quality);
    }
    final fresh = await service
        .refreshTrack(track)
        .timeout(const Duration(seconds: 12));
    if (fresh == null || fresh.audioUrl.isEmpty) {
      throw const AudioResolveException(
          'This track is unavailable right now.');
    }
    return AudioSource(url: fresh.audioUrl, quality: fresh.quality);
  }
}

/// Offline-first resolver: plays a downloaded file when it exists and
/// is large enough to be real audio. Mirrors PlayTorrio's
/// `MusicDownloadService` offline branch in its player controller.
class OfflineAudioResolver implements AudioSourceResolver {
  @override
  Future<AudioSource> resolveTrack(Track track) async {
    try {
      final file =
          MusicDownloadService.instance.getDownloadedTrackFile(track.id);
      if (file != null && file.existsSync() && file.lengthSync() > 100) {
        final rec =
            MusicDownloadService.instance.getDownloadedTrack(track.id);
        final isFlac =
            (rec?.format ?? '').toLowerCase() == 'flac';
        return AudioSource(
          url: file.uri.toString(),
          quality: rec != null
              ? '${rec.quality} (Offline)'
              : 'Offline',
          mime: isFlac ? 'audio/flac' : 'audio/mp4',
        );
      }
    } catch (_) {}
    throw const AudioResolveException('Not downloaded.');
  }
}

/// Qobuz/Eclipse FLAC resolver. Only runs when the user prefers FLAC
/// ([MusicSettings.source]); throws otherwise so the chain falls
/// through to YouTube, exactly like PlayTorrio's FLAC-first branch.
class LosslessAudioResolver implements AudioSourceResolver {
  @override
  Future<AudioSource> resolveTrack(Track track) async {
    if (MusicSettings.instance.source != MusicAudioSource.flac) {
      throw const AudioResolveException('FLAC not preferred.');
    }
    try {
      final flac =
          await LosslessAudioService.instance.resolveLosslessUrl(track);
      if (flac != null && flac.url.isNotEmpty) {
        return AudioSource(
          url: flac.url,
          quality: flac.quality,
          mime: 'audio/flac',
        );
      }
    } catch (_) {}
    throw const AudioResolveException('No lossless stream.');
  }
}

/// YouTube HQ resolver (InnerTube extraction -> ConvertYTMP3 ->
/// provider preview). Runs when the user prefers YouTube, or as the
/// FLAC fallback — the same order as PlayTorrio's `getAudioStream`.
class YoutubeAudioSourceResolver implements AudioSourceResolver {
  final bool onlyWhenPreferred;

  YoutubeAudioSourceResolver({this.onlyWhenPreferred = false});

  @override
  Future<AudioSource> resolveTrack(Track track) async {
    if (onlyWhenPreferred &&
        MusicSettings.instance.source != MusicAudioSource.youtube) {
      throw const AudioResolveException('YouTube not preferred.');
    }
    final yt = await YoutubeStreamResolver.instance.resolveUrl(track);
    if (yt == null || yt.url.isEmpty) {
      throw const AudioResolveException('No YouTube stream.');
    }
    if (yt.url.startsWith('file://') || File(yt.url).existsSync()) {
      return AudioSource(url: yt.url, quality: 'YouTube HQ');
    }
    // Attach the same per-CDN headers PlayTorrio uses so googlevideo
    // hosts accept the media_kit request. media_kit opens plain URLs;
    // the UA travels via query-faithful redirect following.
    YoutubeStreamHttp.streamHeaders(yt.url, userAgent: yt.userAgent);
    return AudioSource(url: yt.url, quality: 'YouTube HQ');
  }
}

/// Full PlayTorrio-order chain: offline -> Audius full track ->
/// FLAC lossless -> YouTube HQ -> provider preview.
AudioSourceResolver playTorrioAudioChain({MusicService? service}) =>
    PrioritizedAudioResolver(resolvers: [
      OfflineAudioResolver(),
      AudiusAudioResolver(),
      LosslessAudioResolver(),
      YoutubeAudioSourceResolver(),
      PreviewAudioResolver(service: service),
    ]);
