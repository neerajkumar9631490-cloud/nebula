enum StreamKind { http, hls, torrent, external }

class StreamResult {
  final String sourceName;
  final String label;
  final String? url;
  final StreamKind kind;
  final String? magnet; // For torrent sources
  final int? fileIndex; // For multi-file torrents

  const StreamResult({
    required this.sourceName,
    required this.label,
    this.url,
    required this.kind,
    this.magnet,
    this.fileIndex,
  });

  bool get playable =>
      (kind == StreamKind.http || kind == StreamKind.hls) && url != null;

  bool get isTorrent => kind == StreamKind.torrent && magnet != null;
}
