import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/stream_result.dart';
import 'local_http_server.dart';
import 'stream_request.dart';
import 'torrent_engine.dart';

/// Central stream orchestrator (the "Stream Manager").
///
/// This is the ONLY core entry point the playback UI talks to:
///
///   direct http/hls  →  returned untouched (player opens it)
///   torrent/magnet   →  engine opens it, local server URL returned
///
/// Either way the player receives a plain HTTP URL and never learns
/// whether BitTorrent was involved.
///
/// Lifecycle & resource rules:
/// * [resolve] is generation-guarded: if [cancel]/[dispose] (or a newer
///   [resolve], e.g. Retry) happens mid-flight, the stale completion is
///   dropped instead of opening the player.
/// * Stats are owned here ([stats]); the UI only listens.
/// * [dispose] cancels stats, drops torrents and frees the notifier.
///   No whole-file buffering is ever requested — the engine serves
///   sequential first-bytes, then on-demand pieces behind a Range-
///   capable localhost URL, so playback starts fast on low-RAM phones.
class StreamManager {
  final TorrentEngine _engine;
  final LocalHttpServer _server;

  /// Live engine stats for the currently resolving/playing torrent.
  /// Null when idle or for direct HTTP streams.
  final ValueNotifier<EngineStats?> stats = ValueNotifier(null);

  StreamSubscription<EngineStats>? _statsSub;
  int _generation = 0;
  bool _disposed = false;

  StreamManager({required TorrentEngine engine, required LocalHttpServer server})
      : _engine = engine,
        _server = server;

  /// Turns a provider [StreamResult] into a player-ready [ResolvedStream].
  /// Returns null when the source cannot be prepared (caller shows its
  /// own failure UI; [onPhase] already received [EnginePhase.error]).
  Future<ResolvedStream?> resolve(
    StreamResult result, {
    EnginePhaseCallback? onPhase,
  }) async {
    final gen = ++_generation;
    bool alive() => !_disposed && gen == _generation;

    stats.value = null;
    await _stopStats();

    // Direct streams need no engine at all.
    if (result.playable && result.url != null) {
      return ResolvedStream(
        url: result.url!,
        kind: result.kind,
        label: result.label,
      );
    }
    if (!result.isTorrent || result.magnet == null) return null;

    final magnet = result.magnet!;
    onPhase?.call(EnginePhase.starting, null);

    if (!await _server.ensureRunning()) {
      if (alive()) onPhase?.call(EnginePhase.error, null);
      return null;
    }
    if (!alive()) return null;

    final url = await _engine.openTorrent(
      magnet: magnet,
      fileIndex: result.fileIndex,
      onPhase: (phase, s) {
        if (s != null) stats.value = s;
        if (alive()) onPhase?.call(phase, s);
      },
    );
    if (!alive()) return null;
    if (url == null) return null; // engine already reported the error phase.

    await _watch(magnet);
    return ResolvedStream(
      url: url,
      kind: StreamKind.torrent,
      label: result.label,
      isLocal: _isLoopback(url),
    );
  }

  /// Cancels any in-flight [resolve] (stale completions are dropped)
  /// without releasing the currently playing stream.
  Future<void> cancel() async {
    _generation++;
    await _stopStats();
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _stopStats();
    stats.dispose();
    try {
      await _engine.release();
    } catch (_) {}
  }

  Future<void> _watch(String magnet) async {
    await _stopStats();
    if (_disposed) return;
    _statsSub = _engine.watchStats(magnet).listen(
          (s) => stats.value = s,
          onError: (_) {},
        );
  }

  Future<void> _stopStats() async {
    try {
      await _statsSub?.cancel();
    } catch (_) {}
    _statsSub = null;
  }

  static bool _isLoopback(String url) =>
      url.startsWith('http://127.0.0.1') ||
      url.startsWith('http://localhost');
}
