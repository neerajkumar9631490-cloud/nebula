import '../core/providers/stream_provider.dart';
import '../models/stream_result.dart';
import '../services/stremio/addon_client.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/catalog_service.dart';

/// [StreamProvider] backed by the user's installed Stremio addons.
///
/// All Stremio-protocol details (manifests, id prefixes, stream paths)
/// live here. Core and UI only see [StreamDiscoveryQuery] in and
/// [ProviderResult] out, so swapping or adding providers never ripples.
class StremioStreamProvider implements StreamProvider {
  final AddonClient _client = AddonClient();

  @override
  String get name => 'Stremio add-ons';

  @override
  Future<ProviderResult> fetchStreams(StreamDiscoveryQuery query) async {
    // Catalog plugins hand us universal ids (e.g. 'tt1234567'),
    // so no external lookup is needed.
    final rawId = query.item.id;
    final imdbId = rawId.startsWith('tt') ? rawId : '';
    final tmdbId =
        rawId.startsWith('tmdb:') ? rawId.substring('tmdb:'.length) : '';

    final notices = <String>[
      if (imdbId.isNotEmpty)
        'Catalog id = $imdbId'
      else if (tmdbId.isNotEmpty)
        'Catalog id = tmdb:$tmdbId'
      else
        'Catalog id = $rawId (direct)',
    ];
    final streams = <StreamResult>[];

    final urls = await AddonManager.getManifestUrls();
    if (urls.isEmpty) {
      notices.add('No add-ons installed yet.');
      return ProviderResult(streams: streams, notices: notices);
    }

    final stremioType = CatalogService.stremioType(query.item.mediaType);
    final jobs = <Future<ProviderResult>>[];
    for (final url in urls) {
      jobs.add(_queryOne(
        url: url,
        stremioType: stremioType,
        imdbId: imdbId,
        tmdbId: tmdbId,
        fallbackId: rawId,
        season: query.season,
        episode: query.episode,
      ));
    }
    for (final r in await Future.wait(jobs)) {
      notices.addAll(r.notices);
      streams.addAll(r.streams);
    }
    // Healthiest torrents first (by advertised seeders), everything
    // else keeps the legacy label order — so the BEST badges land on
    // the fastest sources instead of arbitrary ones.
    streams.sort(_compareStreams);
    return ProviderResult(streams: streams, notices: notices);
  }

  /// Seeders advertised in a source label ('👤 42', '12 seeders',
  /// 'S: 8', '[5 seed]'). Returns -1 when the label says nothing.
  static int parseSeeders(String label) {
    const patterns = [
      '👤\\s*(\\d+)',
      '(\\d+)\\s*seeders?',
      '\\bS\\s*:\\s*(\\d+)',
      '\\[(\\d+)\\s*[Ss]eed',
    ];
    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false).firstMatch(label);
      if (m != null) return int.tryParse(m.group(1)!) ?? -1;
    }
    return -1;
  }

  static int _compareStreams(StreamResult a, StreamResult b) {
    if (a.kind == StreamKind.torrent && b.kind == StreamKind.torrent) {
      final bySeeds =
          parseSeeders(b.label).compareTo(parseSeeders(a.label));
      if (bySeeds != 0) return bySeeds;
    }
    return b.label.compareTo(a.label);
  }

  Future<ProviderResult> _queryOne({
    required String url,
    required String stremioType,
    required String imdbId,
    required String tmdbId,
    required String fallbackId,
    required int season,
    required int episode,
  }) async {
    final base = AddonManager.baseUrlFromManifestUrl(url);
    try {
      final manifest = await _client.fetchManifest(url);
      if (!manifest.supportsStream) {
        return ProviderResult(
            notices: ['${manifest.name}: no stream resource']);
      }
      if (manifest.types.isNotEmpty &&
          !manifest.types.contains(stremioType)) {
        return ProviderResult(
            notices: ['${manifest.name}: skips $stremioType']);
      }
      final streams = await _client.queryStreams(
        baseUrl: base,
        addonName: manifest.name,
        mediaType: stremioType,
        imdbId: imdbId,
        tmdbId: tmdbId,
        idPrefixes: manifest.idPrefixes,
        season: season,
        episode: episode,
        fallbackId: fallbackId,
      );
      return ProviderResult(
          streams: streams, notices: ['${manifest.name}: ${streams.length} found']);
    } catch (_) {
      return ProviderResult(notices: ['$base: unreachable']);
    }
  }
}
