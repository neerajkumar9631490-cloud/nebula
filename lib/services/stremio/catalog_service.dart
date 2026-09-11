import '../../models/media_item.dart';
import 'addon_cache.dart';
import 'addon_client.dart';

export 'addon_client.dart' show AddonCatalog, AddonCatalogExtra, AddonManifest;

/// A titled row of titles sourced from a plugin catalog,
/// e.g. "Top Movies" from Cinemeta.
class CatalogSection {
  final String title;
  final String subtitle;
  final String type; // Stremio type: 'movie' | 'series'
  final List<MediaItem> items;

  /// Provenance for the See-All screen: refetch with option filters
  /// (e.g. genre) and skip pagination straight from the plugin.
  final String baseUrl;
  final AddonCatalog catalog;
  final String addonName;

  const CatalogSection({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.items,
    required this.baseUrl,
    required this.catalog,
    required this.addonName,
  });

  bool get isMovies => type == 'movie';
}

/// Reads movie/series categories, search and meta details from the
/// user's installed catalog plugins. No API key required.
///
/// Speed design: manifests and sections are served from [AddonCache].
/// The first load fetches everything in parallel; repeat visits paint
/// instantly from cache while a background refresh keeps rows fresh.
class CatalogService {
  final AddonClient _client = AddonClient();
  final AddonCache _cache = AddonCache.instance;

  static String stremioType(String mediaType) =>
      mediaType == 'tv' ? 'series' : 'movie';

  Future<CatalogSection?> _safeSection(
      LoadedManifest addon, AddonCatalog catalog) async {
    try {
      final items = await _client
          .fetchCatalog(
            baseUrl: addon.baseUrl,
            type: catalog.type,
            catalogId: catalog.id,
            // Catalogs with required filters (e.g. genre) reject bare
            // requests — satisfy them with the manifest's first options.
            extra: catalog.requiredDefaults,
            client: _cache.client,
          )
          .timeout(const Duration(seconds: 10));
      if (items.isEmpty) return null;
      final isSeries = catalog.type != 'movie';
      final label = isSeries ? 'TV Shows' : 'Movies';
      return CatalogSection(
        title: '${catalog.name} $label',
        subtitle: 'From ${addon.manifest.name}',
        type: isSeries ? 'series' : 'movie',
        items: items,
        baseUrl: addon.baseUrl,
        catalog: catalog,
        addonName: addon.manifest.name,
      );
    } catch (_) {
      return null;
    }
  }

  /// Every category from every catalog plugin, in install order
  /// (movies, then series, then any other catalog types the
  /// plugin advertises, e.g. anime). All addons load in parallel and
  /// each catalog row inside an addon loads in parallel too.
  Future<List<CatalogSection>> loadSections({int catalogsPerType = 3}) async {
    final addons = await _cache.manifests();
    if (addons.isEmpty) return [];
    final perAddon = await Future.wait(
      addons.map((addon) => _sectionsFor(addon, catalogsPerType)),
    );
    final sections = perAddon.expand((s) => s).toList();
    _store(addons, catalogsPerType, sections);
    return sections;
  }

  Future<List<CatalogSection>> _sectionsFor(
      LoadedManifest addon, int catalogsPerType) async {
    if (!addon.manifest.supportsCatalog ||
        addon.manifest.catalogs.isEmpty) {
      return [];
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
    return results.whereType<CatalogSection>().toList();
  }

  /// Instant paint + background refresh. Returns cached sections
  /// immediately when fresh; otherwise loads from network and caches.
  /// Call [onRefresh] to repaint when the background pass finishes.
  Future<List<CatalogSection>> loadSectionsCached({
    int catalogsPerType = 3,
    Future<void> Function(List<CatalogSection> fresh)? onRefresh,
  }) async {
    final addons = await _cache.manifests();
    if (addons.isEmpty) return [];
    final fresh = _cache.freshSections(addons, catalogsPerType);
    if (fresh != null) {
      final sections =
          fresh.map(_fromCached).whereType<CatalogSection>().toList();
      if (onRefresh != null) {
        _reloadSections(addons, catalogsPerType, onRefresh);
      }
      return sections;
    }
    final sections = await _loadAndStore(addons, catalogsPerType);
    return sections;
  }

  Future<void> _reloadSections(
    List<LoadedManifest> addons,
    int perType,
    Future<void> Function(List<CatalogSection> fresh) onRefresh,
  ) async {
    try {
      final sections = await _loadAndStore(addons, perType);
      await onRefresh(sections);
    } catch (_) {}
  }

  Future<List<CatalogSection>> _loadAndStore(
      List<LoadedManifest> addons, int perType) async {
    final perAddon =
        await Future.wait(addons.map((a) => _sectionsFor(a, perType)));
    final sections = perAddon.expand((s) => s).toList();
    _store(addons, perType, sections);
    return sections;
  }

  void _store(List<LoadedManifest> addons, int perType,
      List<CatalogSection> sections) {
    if (sections.isEmpty) return;
    _cache.storeSections(
      addons,
      perType,
      sections
          .map((s) => CachedSection(
                title: s.title,
                subtitle: s.subtitle,
                type: s.type,
                items: s.items,
                baseUrl: s.baseUrl,
                catalog: s.catalog,
                addonName: s.addonName,
              ))
          .toList(),
    );
  }

  CatalogSection? _fromCached(CachedSection c) {
    if (c.items.isEmpty) return null;
    return CatalogSection(
      title: c.title,
      subtitle: c.subtitle,
      type: c.type,
      items: c.items,
      baseUrl: c.baseUrl,
      catalog: c.catalog,
      addonName: c.addonName,
    );
  }

  /// Searches one catalog per advertised type across all catalog
  /// plugins (search-capable ones first).
  Future<List<MediaItem>> searchAll(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final addons = await _cache.manifests();
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
                extra: catalog.requiredDefaults,
                client: _cache.client)
            .timeout(const Duration(seconds: 10))
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
  /// Results are cached for 10 minutes.
  Future<Map<String, dynamic>?> fetchMeta(MediaItem item) async {
    final type = stremioType(item.mediaType);
    final key = '$type:${item.id}';
    final hit = _cache.freshMeta(key);
    if (hit != null) return hit;
    for (final addon in await _cache.manifests()) {
      if (!addon.manifest.supportsMeta) continue;
      if (addon.manifest.types.isNotEmpty &&
          !addon.manifest.types.contains(type)) {
        continue;
      }
      final meta = await _client
          .fetchMeta(
              baseUrl: addon.baseUrl,
              type: type,
              id: item.id,
              client: _cache.client)
          .timeout(const Duration(seconds: 10))
          .catchError((_) => null);
      if (meta != null) {
        _cache.storeMeta(key, meta);
        return meta;
      }
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
