import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/stream_result.dart';

class AddonManifest {
  final String id;
  final String name;
  final String version;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;

  AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.resources,
    required this.types,
    required this.idPrefixes,
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown add-on',
      version: json['version']?.toString() ?? '',
      resources: (json['resources'] as List? ?? [])
          .map((e) => e is String ? e : (e['name']?.toString() ?? ''))
          .toList(),
      types: (json['types'] as List? ?? []).map((e) => e.toString()).toList(),
      idPrefixes: (json['idPrefixes'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  bool get supportsStream => resources.contains('stream');
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

  Future<List<StreamResult>> queryStreams({
    required String baseUrl,
    required String addonName,
    required String mediaType, // 'movie' | 'series'
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

        // Try to extract file index if available
        int? fileIdx;
        if (s['fileIdx'] != null) {
          fileIdx = s['fileIdx'] is int ? s['fileIdx'] : int.tryParse(s['fileIdx'].toString());
        }

        results.add(StreamResult(
          sourceName: addonName,
          label: label.isEmpty ? 'Torrent source' : label,
          kind: StreamKind.torrent,
          magnet: magnet,
          fileIndex: fileIdx ?? 0,
        ));
      } else if (externalUrl != null) {
        results.add(StreamResult(
          sourceName: addonName,
          label: '${label.isEmpty ? 'External link' : label} [external - unsupported]',
          url: externalUrl,
          kind: StreamKind.external,
        ));
      }
    }
    return results;
  }
}
