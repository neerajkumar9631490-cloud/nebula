import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../models/music_models.dart';
import '../services/audio_source_resolver.dart';
import '../services/music_library_service.dart';
import 'music_queue.dart';

export 'music_queue.dart' show RepeatMode;

enum MusicStatus {
  idle,
  loading,
  playing,
  paused,
  buffering,
  completed,
  error,
}

/// Centralized, observable music state. UI rebuilds from [state];
/// per-tick position flows through [positionStream] so the whole UI
/// never rebuilds 4x per second.
class MusicPlayerState {
  final MusicStatus status;
  final QueueItem? current;
  final String? error;
  final bool shuffle;
  final RepeatMode repeat;
  final double volume; // 0..100
  final double rate;
  final int position; // queue position, -1 when none
  final int queueLength;

  const MusicPlayerState({
    this.status = MusicStatus.idle,
    this.current,
    this.error,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.volume = 100,
    this.rate = 1.0,
    this.position = -1,
    this.queueLength = 0,
  });
}

/// App-wide music controller (singleton). Owns the media_kit [Player],
/// the [MusicQueue], resolution, auto-advance and library recording.
/// Survives navigation; lives for the app session.
class MusicPlayerController {
  static final MusicPlayerController _instance =
      MusicPlayerController._internal();
  factory MusicPlayerController() => _instance;
  MusicPlayerController._internal() {
    _subs.add(_player.streams.playing.listen(_onPlaying));
    _subs.add(_player.streams.buffering.listen(_onBuffering));
    _subs.add(_player.streams.completed.listen(_onCompleted));
    _subs.add(_player.streams.error.listen(_onError));
    _subs.add(_player.streams.position.listen((d) {
      _lastPosition = d;
      if (!_position.isClosed) _position.add(d);
    }));
    _subs.add(_player.streams.duration.listen((d) {
      _lastDuration = d ?? Duration.zero;
      if (!_duration.isClosed) _duration.add(d);
    }));
  }

  final Player _player = Player();
  final MusicQueue queue = MusicQueue();
  final PreviewAudioResolver _resolver = PreviewAudioResolver();
  final MusicLibraryService _library = MusicLibraryService();

  final ValueNotifier<MusicPlayerState> state =
      const ValueNotifier(MusicPlayerState());
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _duration =
      StreamController<Duration?>.broadcast();
  final List<StreamSubscription> _subs = [];

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  double _volume = 100;
  double _rate = 1.0;
  int _gen = 0;
  int _skipStreak = 0;

  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _duration.stream;
  Duration get currentPosition => _lastPosition;
  Duration get currentDuration => _lastDuration;

  MusicPlayerState _snapshot(
      {MusicStatus? status, String? error, bool clearError = false}) {
    final s = state.value;
    return MusicPlayerState(
      status: status ?? s.status,
      current: queue.current,
      error: clearError ? null : (error ?? s.error),
      shuffle: queue.shuffle,
      repeat: queue.repeat,
      volume: _volume,
      rate: _rate,
      position: queue.position,
      queueLength: queue.length,
    );
  }

  void _emit(MusicPlayerState s) {
    state.value = s;
  }

  // ── Transport ────────────────────────────────────────────
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _gen++;
    _skipStreak = 0;
    queue.setQueue(tracks,
        startIndex: startIndex.clamp(0, tracks.length - 1));
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    await _playCurrent();
  }

  Future<void> playTrack(Track track) => playTracks([track]);

  Future<void> _playCurrent() async {
    final myGen = _gen;
    final item = queue.current;
    if (item == null) {
      _emit(_snapshot(status: MusicStatus.idle));
      return;
    }
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    AudioSource src;
    try {
      src = await _resolver
          .resolveTrack(item.track)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (myGen != _gen) return;
      return _skipFailed(e is AudioResolveException
          ? e.message
          : 'Could not load "${item.track.title}".');
    }
    if (myGen != _gen) return;
    try {
      await _player.open(Media(src.url)).timeout(
            const Duration(seconds: 20),
          );
      await _player.play();
    } catch (_) {
      if (myGen != _gen) return;
      return _skipFailed('Playback failed.');
    }
    if (myGen != _gen) return;
    _skipStreak = 0;
    unawaited(_library.recordPlay(item.track));
  }

  /// Dead tracks are skipped automatically (bounded — never loops).
  Future<void> _skipFailed(String message) async {
    _skipStreak++;
    final next = queue.next();
    if (_skipStreak > queue.length || next == null || queue.isEmpty) {
      _skipStreak = 0;
      _emit(_snapshot(status: MusicStatus.error, error: message));
      return;
    }
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    await _playCurrent();
  }

  Future<void> toggle() async {
    final s = state.value;
    switch (s.status) {
      case MusicStatus.playing:
        return pause();
      case MusicStatus.completed:
        try {
          await _player.seek(Duration.zero);
          await _player.play();
        } catch (_) {}
        return;
      case MusicStatus.error:
      case MusicStatus.idle:
        if (queue.isEmpty) return;
        _gen++;
        _skipStreak = 0;
        if (queue.current == null) queue.playAt(0);
        return _playCurrent();
      case MusicStatus.paused:
      case MusicStatus.loading:
      case MusicStatus.buffering:
        return play();
    }
  }

  Future<void> play() async {
    try {
      await _player.play();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> stop() async {
    _gen++;
    queue.stopPlayback();
    try {
      await _player.stop();
    } catch (_) {}
    _emit(_snapshot(status: MusicStatus.idle, clearError: true));
  }

  Future<void> next() async {
    _gen++;
    _skipStreak = 0;
    if (queue.next() == null) return;
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    await _playCurrent();
  }

  Future<void> previous() async {
    if (_lastPosition > const Duration(seconds: 3)) {
      try {
        await _player.seek(Duration.zero);
      } catch (_) {}
      return;
    }
    _gen++;
    _skipStreak = 0;
    if (queue.previous() == null) {
      try {
        await _player.seek(Duration.zero);
      } catch (_) {}
      return;
    }
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    await _playCurrent();
  }

  Future<void> playAt(int itemIndex) async {
    _gen++;
    _skipStreak = 0;
    if (queue.playAt(itemIndex) == null) return;
    _emit(_snapshot(status: MusicStatus.loading, clearError: true));
    await _playCurrent();
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (_) {}
  }

  // ── Queue ops (pass-through + state refresh) ─────────────
  void addToQueue(Track track) {
    queue.add(track);
    _emit(_snapshot(clearError: true));
    if (state.value.current == null) {
      _gen++;
      _playCurrent();
    }
  }

  void addAllToQueue(List<Track> tracks) {
    final wasEmpty = queue.isEmpty;
    queue.addAll(tracks);
    _emit(_snapshot(clearError: true));
    if (wasEmpty) {
      _gen++;
      _playCurrent();
    }
  }

  void insertNext(Track track) {
    final wasEmpty = queue.isEmpty;
    queue.insertNext(track);
    _emit(_snapshot(clearError: true));
    if (wasEmpty) {
      _gen++;
      _playCurrent();
    }
  }

  Future<void> removeAt(int itemIndex) async {
    final nextUp = queue.removeAt(itemIndex);
    _gen++;
    _emit(_snapshot(clearError: true));
    if (queue.isEmpty) {
      try {
        await _player.stop();
      } catch (_) {}
      _emit(_snapshot(status: MusicStatus.idle, clearError: true));
    } else if (nextUp != null && state.value.current?.queueId != nextUp.queueId) {
      // Removed the playing track (or position shifted onto another):
      // continue with whatever is cued now.
      await _playCurrent();
    }
  }

  void move(int oldItemIndex, int newItemIndex) {
    queue.move(oldItemIndex, newItemIndex);
    _emit(_snapshot(clearError: true));
  }

  Future<void> clearQueue() => stop();

  void toggleShuffle() {
    queue.toggleShuffle();
    _emit(_snapshot(clearError: true));
  }

  void cycleRepeat() {
    queue.cycleRepeat();
    _emit(_snapshot(clearError: true));
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 100);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
    _emit(_snapshot(clearError: true));
  }

  static const List<double> rates = [1.0, 1.25, 1.5, 1.75, 2.0];

  Future<void> cycleRate() async {
    final i = rates.indexOf(_rate);
    _rate = rates[(i + 1) % rates.length];
    try {
      await _player.setRate(_rate);
    } catch (_) {}
    _emit(_snapshot(clearError: true));
  }

  // ── Library helpers ──────────────────────────────────────
  Future<bool> toggleLike(Track track) => _library.toggleLike(track);
  Future<bool> isLiked(String trackId) => _library.isLiked(trackId);
  Future<List<Track>> recentPlayed({int limit = 15}) =>
      _library.recentPlayed(limit: limit);
  Future<Map<String, Track>> likedTracks() => _library.likedTracks();
  Future<List<Playlist>> playlists() => _library.playlists();
  Future<Playlist> createPlaylist(String name) =>
      _library.createPlaylist(name);
  Future<void> deletePlaylist(String id) => _library.deletePlaylist(id);
  Future<void> addToPlaylist(String playlistId, Track track) =>
      _library.addToPlaylist(playlistId, track);
  Future<void> removeFromPlaylist(String playlistId, String trackId) =>
      _library.removeFromPlaylist(playlistId, trackId);

  // ── Player event mapping ─────────────────────────────────
  void _onPlaying(bool playing) {
    final s = state.value.status;
    if (playing &&
        (s == MusicStatus.loading ||
            s == MusicStatus.paused ||
            s == MusicStatus.buffering)) {
      _emit(_snapshot(status: MusicStatus.playing, clearError: true));
    } else if (!playing && s == MusicStatus.playing) {
      _emit(_snapshot(status: MusicStatus.paused));
    }
  }

  void _onBuffering(bool buffering) {
    final s = state.value.status;
    if (buffering && s == MusicStatus.playing) {
      _emit(_snapshot(status: MusicStatus.buffering));
    } else if (!buffering && s == MusicStatus.buffering) {
      _emit(_snapshot(status: MusicStatus.playing));
    }
  }

  void _onCompleted(bool done) {
    if (!done) return;
    final s = state.value.status;
    if (s != MusicStatus.playing && s != MusicStatus.paused) return;
    if (queue.repeat == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    final next = queue.next();
    if (next == null) {
      _emit(_snapshot(status: MusicStatus.completed));
      return;
    }
    _playCurrent();
  }

  void _onError(String message) {
    final s = state.value.status;
    if (s == MusicStatus.idle) return;
    _emit(_snapshot(
        status: MusicStatus.error,
        error: message.isEmpty ? 'Playback failed.' : message));
  }
}
