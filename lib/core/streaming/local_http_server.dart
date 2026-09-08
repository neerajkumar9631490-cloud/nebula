/// Local HTTP streaming-server contract.
///
/// The server converts streaming-engine output into a normal HTTP stream
/// (e.g. `http://127.0.0.1:<port>/stream/<id>`) with HTTP Range support,
/// so the player (media_kit → ExoPlayer on Android) can seek and buffer
/// exactly like a remote file.
///
/// The server is an internal implementation detail: the core layer only
/// ever hands out plain URLs (see [ResolvedStream]), and the player only
/// ever opens plain URLs.
///
/// NOTE: the bundled TorrServer backend implements this together with
/// [TorrentEngine] because TorrServer ships engine + server in one
/// process. A future split implementation (standalone torrent library +
/// `dart:io`/shelf server with Range handling) can implement the two
/// interfaces separately without touching core or UI code.
abstract class LocalHttpServer {
  /// Starts the loopback server if needed. Returns false when the
  /// server cannot run (the stream then fails gracefully upstream).
  Future<bool> ensureRunning();
}
