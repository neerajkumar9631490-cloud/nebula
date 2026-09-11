import '../core/providers/stream_provider.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../services/stremio/addon_cache.dart';
import '../services/stremio/addon_client.dart';
import '../services/stremio/catalog_service.dart';
import '../services/stremio/stream_verifier.dart';

/// [StreamProvider] backed by the user's installed Stremio addons.
///
/// All Stremio-protocol details (manifests, id prefixes, stream paths)
/// live here. Core and UI only see [StreamDiscoveryQuery] in and
/// [ProviderResult] out, so swapping or adding providers never ripples.
///
/// Speed design: manifests come from [AddonCache] (no refetch per
/// open), every addon is queried in parallel under a total time
/// budget, and results are cached for 90s so reopening the picker
/// is instant.
class StremioStreamProvider implements StreamProvider {
  final AddonClient _client = AddonClient();
  final AddonCache _cache = AddonCache.instance;

  /// Hard budget for a full discovery round. Slow addons are cut off
  /// instead of gating the whole sheet — partial fast results beat
  /// complete slow ones.
  static const discoveryBudget = Duration(seconds: 8);

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

    final stremioType = CatalogService.stremioType(query.item.mediaType);
    final key = AddonCache.streamKey(
        rawId, stremioType, query.season, query.episode);
    final cached = _cache.freshStreams(key);
    if (cached != null && cached.isNotEmpty) {
      return ProviderResult(streams: cached, notices: [...notices, 'Cached']);
    }

    final manifests = await _cache.manifests();
    if (manifests.isEmpty) {
      notices.add('No add-ons installed yet.');
      return ProviderResult(streams: const [], notices: notices);
    }

    final jobs = <Future<ProviderResult>>[];
    for (final m in manifests) {
      jobs.add(_queryOne(
        manifest: m.manifest,
        baseUrl: m.baseUrl,
        stremioType: stremioType,
        imdbId: imdbId,
        tmdbId: tmdbId,
        fallbackId: rawId,
        season: query.season,
        episode: query.episode,
      ).timeout(discoveryBudget, onTimeout: () => const ProviderResult()));
    }
    List<ProviderResult> results;
    try {
      results = await Future.wait(jobs).timeout(
        discoveryBudget + const Duration(seconds: 2),
        onTimeout: () => <ProviderResult>[],
      );
    } catch (_) {
      results = [];
    }
    final streams = <StreamResult>[];
    for (final r in results) {
      notices.addAll(r.notices);
      streams.addAll(r.streams);
    }
    // Dead HTTPS links are probed out automatically and the rest is
    // ordered HTTPS-first, torrents-last (seeders break torrent ties).
    final ordered =
        await StreamVerifier.instance.verifyAndOrder(streams);
    if (ordered.isNotEmpty) _cache.storeStreams(key, ordered);
    return ProviderResult(streams: ordered, notices: notices);
  }

  /// Fire-and-forget warm-up: call when a detail screen opens so the
  /// source picker usually finds a hot cache and paints instantly.
  Future<void> prefetch(
    String rawId,
    String mediaType, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      final stremioType = CatalogService.stremioType(mediaType);
      final key =
          AddonCache.streamKey(rawId, stremioType, season, episode);
      if (_cache.freshStreams(key) != null) return;
      final item = MediaItem(
        id: rawId,
        title: '',
        overview: '',
        mediaType: mediaType,
        releaseYear: '',
      );
      await fetchStreams(
        StreamDiscoveryQuery(item: item, season: season, episode: episode),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<ProviderResult> _queryOne({
    required AddonManifest manifest,
    required String baseUrl,
    required String stremioType,
    required String imdbId,
    required String tmdbId,
    required String fallbackId,
    required int season,
    required int episode,
  }) async {
    try {
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
        baseUrl: baseUrl,
        addonName: manifest.name,
        mediaType: stremioType,
        imdbId: imdbId,
        tmdbId: tmdbId,
        idPrefixes: manifest.idPrefixes,
        season: season,
        episode: episode,
        fallbackId: fallbackId,
        client: _cache.client,
      );
      return ProviderResult(
          streams: streams, notices: ['${manifest.name}: ${streams.length} found']);
    } catch (_) {
      return ProviderResult(notices: ['$baseUrl: unreachable']);
    }
  }
}
