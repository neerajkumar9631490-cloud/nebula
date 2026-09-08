import '../../models/media_item.dart';
import '../../models/stream_result.dart';

/// What the UI wants streams for. Providers translate this into
/// whatever addressing their protocol needs (imdb id, season/episode…).
class StreamDiscoveryQuery {
  final MediaItem item;
  final int season;
  final int episode;

  const StreamDiscoveryQuery({
    required this.item,
    this.season = 1,
    this.episode = 1,
  });

  bool get isTv => item.mediaType == 'tv';
}

/// Everything one provider round produced: the streams plus
/// human-readable per-source status lines for the sources UI.
class ProviderResult {
  final List<StreamResult> streams;
  final List<String> notices;

  const ProviderResult({
    this.streams = const [],
    this.notices = const [],
  });
}

/// Provider/addon contract.
///
/// Providers return *information about* streams ([StreamResult]: URL or
/// magnet, quality hints, subtitles, file info, source type) — they
/// never play video and never touch the player.
///
/// Add or remove providers without touching core or UI: implement this
/// interface and register the instance where streams are discovered.
abstract class StreamProvider {
  String get name;
  Future<ProviderResult> fetchStreams(StreamDiscoveryQuery query);
}
