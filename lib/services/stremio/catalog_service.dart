import '../../models/media_item.dart';
import 'addon_client.dart';
import 'addon_manager.dart';

/// A titled row of titles sourced from a plugin catalog,
/// e.g. "Top Movies" from Cinemeta.
class CatalogSection {
  final String title;
  final String subtitle;
  final String type; // Stremio type: 'movie' | 'series'
  final List<MediaItem> items;

  const CatalogSection({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.items,
  });

  bool get isMovies => type == 'movie';
}

/// Reads movie/series categories, search and meta details from the
/// user's installed catalog plugins. No API key required.
class CatalogService {
  final AddonClient _client = AddonClient();

  static String stremioType(String mediaType) =>
      mediaType == 'tv' ? 'series' : 'movie';

  Future<List<_LoadedAddon>> _loadAddons() async {
    final urls = await AddonManager.getManifestUrls();
    final out = <_LoadedAddon>[];
    for (final url in urls) {
      try {
        final manifest = await _client.fetchManifest(url);
        out.add(_LoadedAddon(
            AddonManager.baseUrlFromManifestUrl(url), manifest));
      } catch (_) {
        // Unreachable plugins are skipped; the rest still load.
      }
    }
    return out;
  }

  Future<CatalogSection?> _safeSection(
      _LoadedAddon addon, AddonCatalog catalog) async {
    try {
      final items = await _client.fetchCatalog(
        baseUrl: addon.baseUrl,
        type: catalog.type,
        catalogId: catalog.id,
        // Catalogs with required filters (e.g. genre) reject bare
        // requests — satisfy them with the manifest's first options.
        extra: catalog.requiredDefaults,
      );
      if (items.isEmpty) return null;
      final isSeries = catalog.type != 'movie';
      final label = isSeries ? 'TV Shows' : 'Movies';
      return CatalogSection(
        title: '${catalog.name} $label',
        subtitle: 'From ${addon.manifest.name}',
        type: isSeries ? 'series' : 'movie',
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  /// Every category from every catalog plugin, in install order
  /// (movies, then series, then any other catalog types the
  /// plugin advertises, e.g. anime).
  Future<List<CatalogSection>> loadSections({int catalogsPerType = 3}) async {
    final addons = await _loadAddons();
    final sections = <CatalogSection>[];
    for (final addon in addons) {
      if (!addon.manifest.supportsCatalog ||
          addon.manifest.catalogs.isEmpty) {
        continue;
      }
      final usable = addon.manifest.catalogs
          .where((c) => c.type.isNotEmpty && c.id.isNotEmpty)
          .toList();
      final movies =
          usable.where((c) => c.type == 'movie').take(catalogsPerType);
      final series =
          usable.where((c) => c.type == 'series').take(catalogsPerType);
      final others = usable
          .where((c) => c.type != 'movie' && c.type != 'series')
          .take(catalogsPerType);
      final results = await Future.wait([
        for (final c in [...movies, ...series, ...others])
          _safeSection(addon, c)
      ]);
      for (final s in results) {
        if (s != null) sections.add(s);
      }
    }
    return sections;
  }

  /// Searches one catalog per advertised type across all catalog
  /// plugins (search-capable ones first).
  Future<List<MediaItem>> searchAll(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final addons = await _loadAddons();
    final jobs = <Future<List<MediaItem>>>[];
    for (final addon in addons) {
      if (!addon.manifest.supportsCatalog) continue;
      final picks = _pickSearchCatalogs(addon.manifest);
      for (final catalog in picks) {
        jobs.add(_client
            .fetchCatalog(
                baseUrl: addon.baseUrl,
                type: catalog.type,
                catalogId: catalog.id,
                search: q,
                extra: catalog.requiredDefaults)
            .catchError((_) => <MediaItem>[]));
      }
    }
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final list in await Future.wait(jobs)) {
      for (final item in list) {
        if (seen.add(item.id)) out.add(item);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// Full meta details (background, genres, cast, episode lists)
  /// from the first meta-capable plugin that knows this title.
  Future<Map<String, dynamic>?> fetchMeta(MediaItem item) async {
    final type = stremioType(item.mediaType);
    for (final addon in await _loadAddons()) {
      if (!addon.manifest.supportsMeta) continue;
      if (addon.manifest.types.isNotEmpty &&
          !addon.manifest.types.contains(type)) {
        continue;
      }
      final meta = await _client.fetchMeta(
          baseUrl: addon.baseUrl, type: type, id: item.id);
      if (meta != null) return meta;
    }
    return null;
  }

  /// One searchable catalog per advertised type: search-capable
  /// catalogs first, preferring the 'top' catalog. Capped so a wall
  /// of plugins can't flood the network.
  List<AddonCatalog> _pickSearchCatalogs(AddonManifest manifest) {
    final byType = <String, List<AddonCatalog>>{};
    for (final c in manifest.catalogs) {
      if (c.type.isEmpty || c.id.isEmpty) continue;
      (byType[c.type] ??= <AddonCatalog>[]).add(c);
    }
    final picks = <AddonCatalog>[];
    for (final list in byType.values) {
      list.sort((a, b) {
        final aScore = (a.supportsSearch ? 0 : 1) * 10 +
            (a.id.toLowerCase().contains('top') ? 0 : 1);
        final bScore = (b.supportsSearch ? 0 : 1) * 10 +
            (b.id.toLowerCase().contains('top') ? 0 : 1);
        return aScore.compareTo(bScore);
      });
      picks.add(list.first);
      if (picks.length >= 4) break;
    }
    return picks;
  }
}

class _LoadedAddon {
  final String baseUrl;
  final AddonManifest manifest;
  const _LoadedAddon(this.baseUrl, this.manifest);
}
