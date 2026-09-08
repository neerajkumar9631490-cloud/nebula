import 'subtitle_track.dart';

enum StreamKind { http, hls, torrent, external }

class StreamResult {
  final String sourceName;
  final String label;
  final String? url;
  final StreamKind kind;
  final String? magnet;
  final int? fileIndex;

  /// Subtitle tracks advertised with this stream, if any.
  final List<SubtitleTrack> subtitles;

  const StreamResult({
    required this.sourceName,
    required this.label,
    this.url,
    required this.kind,
    this.magnet,
    this.fileIndex,
    this.subtitles = const [],
  });

  bool get playable =>
      (kind == StreamKind.http || kind == StreamKind.hls) && url != null;
  
  bool get isTorrent => kind == StreamKind.torrent && magnet != null;
}
