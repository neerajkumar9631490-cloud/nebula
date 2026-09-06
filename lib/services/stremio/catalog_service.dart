import '../models/media_item.dart';
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
      );
      if (items.isEmpty) return null;
      final label = catalog.type == 'series' ? 'TV Shows' : 'Movies';
      return CatalogSection(
        title: '${catalog.name} $label',
        subtitle: 'From ${addon.manifest.name}',
        type: catalog.type == 'series' ? 'series' : 'movie',
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  /// Every category from every catalog plugin, in install order
  /// (movies before series per plugin).
  Future<List<CatalogSection>> loadSections({int catalogsPerType = 3}) async {
    final addons = await _loadAddons();
    final sections = <CatalogSection>[];
    for (final addon in addons) {
      if (!addon.manifest.supportsCatalog ||
          addon.manifest.catalogs.isEmpty) {
        continue;
      }
      final movies = addon.manifest.catalogs
          .where((c) => c.type == 'movie' && c.id.isNotEmpty)
          .take(catalogsPerType)
          .toList();
      final series = addon.manifest.catalogs
          .where((c) => c.type == 'series' && c.id.isNotEmpty)
          .take(catalogsPerType)
          .toList();
      final results = await Future.wait(
          [for (final c in [...movies, ...series]) _safeSection(addon, c)]);
      for (final s in results) {
        if (s != null) sections.add(s);
      }
    }
    return sections;
  }

  /// Searches movie + series catalogs across all catalog plugins.
  Future<List<MediaItem>> searchAll(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final addons = await _loadAddons();
    final jobs = <Future<List<MediaItem>>>[];
    for (final addon in addons) {
      if (!addon.manifest.supportsCatalog) continue;
      final movie = _pickCatalog(addon.manifest, 'movie');
      final series = _pickCatalog(addon.manifest, 'series');
      if (movie != null) {
        jobs.add(_client
            .fetchCatalog(
                baseUrl: addon.baseUrl,
                type: 'movie',
                catalogId: movie.id,
                search: q)
            .catchError((_) => <MediaItem>[]));
      }
      if (series != null) {
        jobs.add(_client
            .fetchCatalog(
                baseUrl: addon.baseUrl,
                type: 'series',
                catalogId: series.id,
                search: q)
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

  AddonCatalog? _pickCatalog(AddonManifest manifest, String type) {
    final list =
        manifest.catalogs.where((c) => c.type == type && c.id.isNotEmpty).toList();
    if (list.isEmpty) return null;
    for (final c in list) {
      if (c.id.toLowerCase().contains('top')) return c;
    }
    return list.first;
  }
}

class _LoadedAddon {
  final String baseUrl;
  final AddonManifest manifest;
  const _LoadedAddon(this.baseUrl, this.manifest);
}
