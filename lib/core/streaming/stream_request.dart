import '../../models/stream_result.dart';

/// Lifecycle phases of turning a [StreamResult] into a playable URL.
/// UI-facing: the player shows these, but never drives engine internals.
enum EnginePhase { starting, metadata, buffering, ready, error }

/// Engine-agnostic live stats for a torrent-backed stream.
/// Deliberately mirrors only what playback UI needs — no plugin types.
class EngineStats {
  final double speedMbps;
  final int activePeers;
  final double progress; // 0.0 – 1.0 of the whole torrent

  const EngineStats({
    required this.speedMbps,
    required this.activePeers,
    required this.progress,
  });

  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(1)} MB/s'
      : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';
}

/// A stream the player can open directly.
///
/// [url] is ALWAYS an http(s) URL — either the provider's direct file,
/// or a localhost URL served by the streaming engine for torrents.
/// The player must never need to know which one it is.
class ResolvedStream {
  final String url;
  final StreamKind kind;
  final String label;

  /// True when [url] points at the in-app local HTTP server.
  final bool isLocal;

  const ResolvedStream({
    required this.url,
    required this.kind,
    required this.label,
    this.isLocal = false,
  });
}
