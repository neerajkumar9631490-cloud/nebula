import '../models/music_models.dart';
import 'music_service.dart';

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
