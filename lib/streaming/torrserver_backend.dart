import 'dart:async';
import '../core/streaming/local_http_server.dart';
import '../core/streaming/stream_request.dart';
import '../core/streaming/torrent_engine.dart';
import '../services/torrent/torrent_service.dart';

/// Streaming-layer backend: TorrServer as [TorrentEngine] + [LocalHttpServer].
///
/// TorrServer ships the engine and the loopback HTTP server in one
/// process, so one class implements both contracts by delegating to the
/// existing [TorrentService] (whose download behavior is unchanged:
/// metadata → best file → first playable bytes → Range-capable
/// localhost URL; whole-file download is never required).
///
/// Replaceability: to swap engines, implement [TorrentEngine] (and
/// [LocalHttpServer]) against another library and inject it into
/// [StreamManager] — core and UI code stays untouched.
class TorrServerBackend implements TorrentEngine, LocalHttpServer {
  final TorrentService _svc = TorrentService();

  @override
  Future<bool> ensureReady() async {
    if (!await _svc.initialize()) return false;
    // Best-effort throughput tuning; streaming works without it.
    try {
      await _svc.applyPerformanceProfile();
    } catch (_) {}
    return true;
  }

  @override
  Future<bool> ensureRunning() => _svc.initialize();

  @override
  Future<String?> openTorrent({
    required String magnet,
    int? fileIndex,
    EnginePhaseCallback? onPhase,
  }) {
    return _svc.startStream(
      magnet: magnet,
      fileIndex: fileIndex,
      onPhase: onPhase == null
          ? null
          : (phase, stats) => onPhase(
                _toPhase(phase),
                stats == null ? null : _toStats(stats),
              ),
    );
  }

  @override
  Stream<EngineStats> watchStats(String magnetOrHash) =>
      _svc.statsStream(magnetOrHash).map(_toStats);

  @override
  Future<void> release() => _svc.cleanup();

  static EnginePhase _toPhase(TorrentPhase phase) => switch (phase) {
        TorrentPhase.engine => EnginePhase.starting,
        TorrentPhase.metadata => EnginePhase.metadata,
        TorrentPhase.peers => EnginePhase.buffering,
        TorrentPhase.ready => EnginePhase.ready,
        TorrentPhase.error => EnginePhase.error,
      };

  static EngineStats _toStats(TorrentStats stats) => EngineStats(
        speedMbps: stats.speedMbps,
        activePeers: stats.activePeers,
        progress: stats.progress,
      );
}
