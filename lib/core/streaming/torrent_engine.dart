import 'dart:async';
import 'stream_request.dart';

/// Phase + stats callback for torrent startup.
/// In Dart this callback (plus [Stream]/[Future]) plays the role
/// coroutines/Flows play in a native Android stack.
typedef EnginePhaseCallback = void Function(
    EnginePhase phase, EngineStats? stats);

/// Torrent engine contract.
///
/// Implementations download/request ONLY the pieces needed for playback
/// (sequential first-bytes, then the rest on demand) and must support
/// seeking (via byte-range–capable output), cancellation and cleanup —
/// without ever pulling the whole file before playback starts.
///
/// The engine exposes play-ready output through the [LocalHttpServer]
/// side; see `local_http_server.dart`.
abstract class TorrentEngine {
  /// Starts the engine process if needed. Returns false when the
  /// engine cannot run on this device.
  Future<bool> ensureReady();

  /// Adds the torrent, waits for metadata + first playable bytes, then
  /// returns the local HTTP URL serving the selected file.
  /// Returns null (after reporting [EnginePhase.error]) on failure.
  /// Must be safe to abandon: see [StreamManager]'s generation guard.
  Future<String?> openTorrent({
    required String magnet,
    int? fileIndex,
    EnginePhaseCallback? onPhase,
  });

  /// Live stats for an opened torrent. The returned subscription must
  /// be cancellable at any time (player exit, retry, dispose).
  Stream<EngineStats> watchStats(String magnetOrHash);

  /// Drops active torrents and frees engine resources.
  /// Must be idempotent and safe to call more than once.
  Future<void> release();
}
