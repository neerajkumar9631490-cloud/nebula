enum StreamKind { http, hls, torrent, external }

class StreamResult {
  final String sourceName;
  final String label;
  final String? url;
  final StreamKind kind;

  const StreamResult({
    required this.sourceName,
    required this.label,
    this.url,
    required this.kind,
  });

  bool get playable =>
      (kind == StreamKind.http || kind == StreamKind.hls) && url != null;
}
