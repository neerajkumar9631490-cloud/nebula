import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/media_item.dart';
import '../../models/stream_result.dart';
import '../bridge/host_bridge.dart';
import '../providers/stream_provider.dart';
import '../streaming/local_http_server.dart';
import '../streaming/stream_manager.dart';
import '../streaming/stream_request.dart';
import '../streaming/torrent_engine.dart';

// ─────────────────────────────────────────────────────────────
// ACTIONS — the runtime's public API surface.
// UI dispatches these; effect completions come back as the
// internal (but public, like stremio-core's Msg) actions below.
// ─────────────────────────────────────────────────────────────

/// UI → Runtime intent. Exhaustively handled by [AppRuntime.dispatch].
sealed class AppAction {
  const AppAction();
}

/// UI: start stream discovery for a title.
final class DiscoverStreams extends AppAction {
  final MediaItem item;
  final int season;
  final int episode;
  const DiscoverStreams(
      {required this.item, this.season = 1, this.episode = 1});
}

/// UI: re-run the last discovery.
final class RetryDiscovery extends AppAction {
  const RetryDiscovery();
}

/// UI: turn a provider result into a playable URL.
final class ResolveStream extends AppAction {
  final StreamResult result;
  const ResolveStream(this.result);
}

/// UI: abandon an in-flight resolve (exit/retry race guard).
final class CancelPlaybackPrep extends AppAction {
  const CancelPlaybackPrep();
}

/// Internal: provider round finished.
final class DiscoverySucceeded extends AppAction {
  final List<StreamResult> streams;
  final List<String> notices;
  const DiscoverySucceeded(this.streams, this.notices);
}

/// Internal: provider round threw.
final class DiscoveryFailed extends AppAction {
  final String message;
  const DiscoveryFailed(this.message);
}

/// Internal: engine reported a new phase.
final class ResolveProgressed extends AppAction {
  final EnginePhase phase;
  const ResolveProgressed(this.phase);
}

/// Internal: a playable URL is ready.
final class ResolveSucceeded extends AppAction {
  final ResolvedStream stream;
  const ResolveSucceeded(this.stream);
}

/// Internal: resolution failed.
final class ResolveFailed extends AppAction {
  final String message;
  const ResolveFailed(this.message);
}

// ─────────────────────────────────────────────────────────────
// STATE — snapshots the UI renders. Immutable, replaced wholesale.
// ─────────────────────────────────────────────────────────────

enum DiscoveryStatus { idle, loading, loaded, failed }

/// Stream-discovery slice of [AppState].
final class DiscoveryState {
  final DiscoveryStatus status;
  final List<StreamResult> streams;
  final List<String> notices;
  final String? error;

  const DiscoveryState({
    this.status = DiscoveryStatus.idle,
    this.streams = const [],
    this.notices = const [],
    this.error,
  });
}

enum PlaybackStatus { idle, resolving, ready, failed }

/// Playback-preparation slice of [AppState].
final class PlaybackState {
  final PlaybackStatus status;
  final EnginePhase phase;
  final ResolvedStream? stream;
  final String? error;

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.phase = EnginePhase.starting,
    this.stream,
    this.error,
  });
}

/// The single state snapshot. UI renders this and nothing else.
final class AppState {
  final DiscoveryState discovery;
  final PlaybackState playback;

  const AppState({
    this.discovery = const DiscoveryState(),
    this.playback = const PlaybackState(),
  });

  AppState copyWith({DiscoveryState? discovery, PlaybackState? playback}) =>
      AppState(
        discovery: discovery ?? this.discovery,
        playback: playback ?? this.playback,
      );
}

// ─────────────────────────────────────────────────────────────
// EFFECTS — explicit descriptions of side effects. The runtime
// executes them and feeds results back as internal actions.
// ─────────────────────────────────────────────────────────────

/// Side effect the runtime must run. Never executed by UI directly.
sealed class AppEffect {
  const AppEffect();
}

/// Run provider discovery for [query].
final class FetchStreamsEffect extends AppEffect {
  final StreamDiscoveryQuery query;
  const FetchStreamsEffect(this.query);
}

/// Turn [result] into a playable URL via the [StreamManager].
final class ResolveStreamEffect extends AppEffect {
  final StreamResult result;
  const ResolveStreamEffect(this.result);
}

// ─────────────────────────────────────────────────────────────
// EVENTS — noteworthy happenings for platform/bridge consumers
// (toasts, logging, analytics). State stays the source of truth.
// ─────────────────────────────────────────────────────────────

/// Noteworthy runtime happening. Consumed via [AppRuntime.events].
sealed class CoreEvent {
  const CoreEvent();
}

/// A discovery or playback flow failed. UI shows these as toasts.
final class CoreErrorEvent extends CoreEvent {
  final String message;

  /// 'discovery' | 'playback'
  final String source;

  const CoreErrorEvent(this.message, this.source);
}

// ─────────────────────────────────────────────────────────────
// RUNTIME — UI --Action--> update() --Effect--> execute --Msg-->
// update() --NewState/Event--> UI. Models never touch the UI and
// the UI never touches providers or the engine.
// ─────────────────────────────────────────────────────────────

class AppRuntime {
  final StreamProvider discovery;
  final HostBridge bridge;
  final StreamManager _playback;

  final StreamController<AppState> _states =
      StreamController<AppState>.broadcast();
  final StreamController<CoreEvent> _events =
      StreamController<CoreEvent>.broadcast();

  AppState _state = const AppState();
  StreamDiscoveryQuery? _lastQuery;
  bool _disposed = false;

  AppRuntime({
    required this.discovery,
    required TorrentEngine engine,
    required LocalHttpServer server,
    required this.bridge,
  }) : _playback = StreamManager(engine: engine, server: server);

  /// Latest snapshot (synchronously fresh after [dispatch] returns).
  AppState get state => _state;

  /// Every new snapshot, in order. UI rebuilds from these.
  Stream<AppState> get states => _states.stream;

  /// Noteworthy happenings (error toasts, …).
  Stream<CoreEvent> get events => _events.stream;

  /// Live engine stats for the resolving/playing torrent.
  ValueListenable<EngineStats?> get engineStats => _playback.stats;

  /// The single entry point for UI intent.
  void dispatch(AppAction action) {
    if (_disposed) return;
    switch (action) {
      case DiscoverStreams(item: var item, season: var season, episode: var episode):
        _lastQuery =
            StreamDiscoveryQuery(item: item, season: season, episode: episode);
        _emit(_state.copyWith(
            discovery:
                const DiscoveryState(status: DiscoveryStatus.loading)));
        _execute(FetchStreamsEffect(_lastQuery!));
      case RetryDiscovery():
        final query = _lastQuery;
        if (query == null) return;
        _emit(_state.copyWith(
            discovery:
                const DiscoveryState(status: DiscoveryStatus.loading)));
        _execute(FetchStreamsEffect(query));
      case ResolveStream(result: var result):
        _emit(_state.copyWith(
            playback: const PlaybackState(
                status: PlaybackStatus.resolving,
                phase: EnginePhase.starting)));
        _execute(ResolveStreamEffect(result));
      case CancelPlaybackPrep():
        _playback.cancel();
        _emit(_state.copyWith(playback: const PlaybackState()));
      case DiscoverySucceeded(streams: var streams, notices: var notices):
        _emit(_state.copyWith(
            discovery: DiscoveryState(
                status: DiscoveryStatus.loaded,
                streams: streams,
                notices: notices)));
      case DiscoveryFailed(message: var message):
        _emit(_state.copyWith(
            discovery: DiscoveryState(
                status: DiscoveryStatus.failed, error: message)));
        _events.add(CoreErrorEvent(message, 'discovery'));
      case ResolveProgressed(phase: var phase):
        _emit(_state.copyWith(
            playback: PlaybackState(
                status: PlaybackStatus.resolving, phase: phase)));
      case ResolveSucceeded(stream: var stream):
        _emit(_state.copyWith(
            playback: PlaybackState(
                status: PlaybackStatus.ready,
                phase: EnginePhase.ready,
                stream: stream)));
      case ResolveFailed(message: var message):
        _emit(_state.copyWith(
            playback: PlaybackState(
                status: PlaybackStatus.failed,
                phase: EnginePhase.error,
                error: message)));
        _events.add(CoreErrorEvent(message, 'playback'));
    }
  }

  /// Effect interpreter: runs side effects, feeds results back as
  /// internal actions. The only place providers/engine are touched.
  Future<void> _execute(AppEffect effect) async {
    switch (effect) {
      case FetchStreamsEffect(query: var query):
        try {
          final result = await discovery.fetchStreams(query);
          dispatch(DiscoverySucceeded(result.streams, result.notices));
        } catch (e) {
          dispatch(DiscoveryFailed(e.toString()));
        }
      case ResolveStreamEffect(result: var result):
        try {
          final resolved = await _playback.resolve(
            result,
            onPhase: (phase, _) => dispatch(ResolveProgressed(phase)),
          );
          if (resolved == null) {
            dispatch(const ResolveFailed('Stream failed to load'));
          } else {
            dispatch(ResolveSucceeded(resolved));
          }
        } catch (e) {
          dispatch(ResolveFailed(e.toString()));
        }
    }
  }

  void _emit(AppState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _playback.dispose();
    await _states.close();
    await _events.close();
  }
}
