enum StreamKind { http, hls, torrent, external }

class StreamResult {
  final String sourceName;
  final String label;
  final String? url;
  final StreamKind kind;
  final String? magnet; // For torrent sources

  const StreamResult({
    required this.sourceName,
    required this.label,
    this.url,
    required this.kind,
    this.magnet,
  });

  bool get playable =>
      (kind == StreamKind.http || kind == StreamKind.hls) && url != null;
  
  bool get isTorrent => kind == StreamKind.torrent && magnet != null;
}
