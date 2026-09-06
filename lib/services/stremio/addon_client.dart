import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/media_item.dart';
import '../../models/stream_result.dart';

class AddonCatalog {
  final String type; // Stremio type: 'movie' | 'series' | ...
  final String id; // e.g. 'top'
  final String name; // e.g. 'Top'

  const AddonCatalog({required this.type, required this.id, required this.name});

  factory AddonCatalog.fromJson(Map<String, dynamic> json) => AddonCatalog(
        type: json['type']?.toString() ?? '',
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class AddonManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<AddonCatalog> catalogs;

  AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    required this.resources,
    required this.types,
    required this.idPrefixes,
    this.catalogs = const [],
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown add-on',
      version: json['version']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      resources: (json['resources'] as List? ?? [])
          .map((e) => e is String ? e : (e['name']?.toString() ?? ''))
          .toList(),
      types: (json['types'] as List? ?? []).map((e) => e.toString()).toList(),
      idPrefixes: (json['idPrefixes'] as List? ?? []).map((e) => e.toString()).toList(),
      catalogs: (json['catalogs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AddonCatalog.fromJson)
          .toList(),
    );
  }

  bool get supportsStream => resources.contains('stream');
  bool get supportsMeta => resources.contains('meta');
  bool get supportsCatalog =>
      resources.contains('catalog') || catalogs.isNotEmpty;
}

class AddonClient {
  Future<AddonManifest> fetchManifest(String manifestUrl) async {
    final res = await http
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('manifest HTTP ${res.statusCode}');
    }
    return AddonManifest.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }

  /// Fetches a catalog page: `$baseUrl/catalog/<type>/<id>.json`.
  /// With [search], queries `$baseUrl/catalog/<type>/<id>/search=<q>.json`
  /// (supported by catalog plugins such as Cinemeta).
  Future<List<MediaItem>> fetchCatalog({
    required String baseUrl,
    required String type,
    required String catalogId,
    String? search,
  }) async {
    var path = '/catalog/$type/$catalogId.json';
    if (search != null && search.trim().isNotEmpty) {
      path =
          '/catalog/$type/$catalogId/search=${Uri.encodeComponent(search.trim())}.json';
    }
    final res = await http
        .get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body);
    if (data is! Map<String, dynamic>) return [];
    final metas = data['metas'];
    if (metas is! List) return [];

    final items = <MediaItem>[];
    for (final m in metas.whereType<Map<String, dynamic>>()) {
      try {
        final item = MediaItem.fromCinemeta(m, type);
        if (item.id.isNotEmpty &&
            item.title.trim().isNotEmpty &&
            item.title != 'Unknown') {
          items.add(item);
        }
      } catch (_) {}
    }
    return items;
  }

  /// Fetches full meta details: `$baseUrl/meta/<type>/<id>.json`.
  /// Returns the inner `meta` object (background, logo, cast, videos…).
  Future<Map<String, dynamic>?> fetchMeta({
    required String baseUrl,
    required String type,
    required String id,
  }) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/meta/$type/$id.json'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      if (data is Map<String, dynamic> &&
          data['meta'] is Map<String, dynamic>) {
        return (data['meta'] as Map).cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<StreamResult>> queryStreams({
    required String baseUrl,
    required String addonName,
    required String mediaType,
    required String imdbId,
    required String tmdbId,
    required List<String> idPrefixes,
    int season = 1,
    int episode = 1,
  }) async {
    String? id;
    if (idPrefixes.contains('tt') && imdbId.isNotEmpty) {
      id = imdbId;
    } else if (idPrefixes.contains('tmdb') && tmdbId.isNotEmpty) {
      id = tmdbId;
    } else if (idPrefixes.isEmpty && imdbId.isNotEmpty) {
      id = imdbId;
    }
    if (id == null) return [];

    final path = mediaType == 'movie'
        ? '/stream/movie/$id.json'
        : '/stream/series/$id:$season:$episode.json';

    final res = await http
        .get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);
    final streams = data['streams'];
    if (streams is! List) return [];

    final results = <StreamResult>[];
    for (final s in streams) {
      if (s is! Map<String, dynamic>) continue;
      final url = s['url']?.toString();
      final infoHash = s['infoHash']?.toString();
      final externalUrl = s['externalUrl']?.toString();
      final label = [s['name'], s['title'], s['description']]
          .whereType<String>()
          .where((e) => e.trim().isNotEmpty)
          .join(' • ');

      if (url != null && url.startsWith('http')) {
        final kind = url.contains('.m3u8') ? StreamKind.hls : StreamKind.http;
        results.add(StreamResult(
          sourceName: addonName,
          label: label.isEmpty ? 'Stream' : label,
          url: url,
          kind: kind,
        ));
      } else if (infoHash != null || (url != null && url.startsWith('magnet:'))) {
        final magnet = url?.startsWith('magnet:') == true
            ? url
            : 'magnet:?xt=urn:btih:$infoHash';
        results.add(StreamResult(
          sourceName: addonName,
          label: label.isEmpty ? 'Torrent source' : label,
          kind: StreamKind.torrent,
          magnet: magnet,
        ));
      } else if (externalUrl != null) {
        results.add(StreamResult(
          sourceName: addonName,
          label: '${label.isEmpty ? 'External link' : label} [external]',
          url: externalUrl,
          kind: StreamKind.external,
        ));
      }
    }
    return results;
  }
}
