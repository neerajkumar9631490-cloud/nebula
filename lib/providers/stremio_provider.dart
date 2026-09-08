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
        'No external id for this title',
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
        season: query.season,
        episode: query.episode,
      ));
    }
    for (final r in await Future.wait(jobs)) {
      notices.addAll(r.notices);
      streams.addAll(r.streams);
    }
    // Best quality first for a premium feel.
    streams.sort((a, b) => b.label.compareTo(a.label));
    return ProviderResult(streams: streams, notices: notices);
  }

  Future<ProviderResult> _queryOne({
    required String url,
    required String stremioType,
    required String imdbId,
    required String tmdbId,
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
      );
      return ProviderResult(
          streams: streams, notices: ['${manifest.name}: ${streams.length} found']);
    } catch (_) {
      return ProviderResult(notices: ['$base: unreachable']);
    }
  }
}
