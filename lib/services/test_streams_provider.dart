import '../models/stream_result.dart';

class TestStreamsProvider {
  static const name = 'Built-in Test (public domain)';

  static List<StreamResult> streamsFor(String title) {
    return [
      StreamResult(
        sourceName: name,
        label: 'TEST MP4: Big Buck Bunny (open movie) for "$title"',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        kind: StreamKind.http,
      ),
      StreamResult(
        sourceName: name,
        label: 'TEST MP4: Sintel (open movie)',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
        kind: StreamKind.http,
      ),
      StreamResult(
        sourceName: name,
        label: 'TEST HLS: adaptive bitrate test stream',
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        kind: StreamKind.hls,
      ),
    ];
  }
}
