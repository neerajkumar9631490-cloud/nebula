import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class TMDBException implements Exception {
  final String message;
  TMDBException(this.message);

  @override
  String toString() => message;
}

class TMDBService {
  final String apiKey;
  TMDBService(this.apiKey);

  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _imgUrl = 'https://image.tmdb.org/t/p/w500';

  String getImgUrl(String? path) => path != null ? '$_imgUrl$path' : '';

  Future<Map<String, dynamic>> _getJson(String path, {Map<String, String>? query}) async {
    final params = <String, String>{
      'api_key': apiKey,
      'language': 'en-US',
      ...?query,
    };
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);

    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          return json.decode(res.body) as Map<String, dynamic>;
        }
        String msg = 'TMDB error ${res.statusCode}';
        try {
          final body = json.decode(res.body);
          msg = body['status_message']?.toString() ?? msg;
        } catch (_) {}
        throw TMDBException(msg);
      } catch (e) {
        if (e is TMDBException) rethrow;
        lastError = e;
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw TMDBException('Network error: $lastError');
  }

  Future<bool> validateKey() async {
    try {
      await _getJson('/configuration');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<MediaItem>> getTrending() async =>
      _parseResults(await _getJson('/trending/all/week'));

  Future<List<MediaItem>> getPopularMovies() async =>
      _parseResults(await _getJson('/movie/popular', query: {'page': '1'}), forcedType: 'movie');

  Future<List<MediaItem>> getPopularTv() async =>
      _parseResults(await _getJson('/tv/popular', query: {'page': '1'}), forcedType: 'tv');

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return _parseResults(await _getJson('/search/multi', query: {
      'query': query.trim(),
      'include_adult': 'false',
      'page': '1',
    }));
  }

  Future<String> getExternalId(String mediaType, int id) async {
    final path = mediaType == 'tv' ? '/tv/$id/external_ids' : '/movie/$id/external_ids';
    final data = await _getJson(path);
    return data['imdb_id']?.toString() ?? '';
  }

  List<MediaItem> _parseResults(Map<String, dynamic> data, {String? forcedType}) {
    final raw = data['results'];
    if (raw is! List) return [];

    return raw
        .whereType<Map<String, dynamic>>()
        .where((e) {
          final type = forcedType ?? e['media_type'];
          return type == 'movie' || type == 'tv' || e['title'] != null || e['name'] != null;
        })
        .map((e) => MediaItem.fromJson({
              ...e,
              if (forcedType != null) 'media_type': forcedType,
            }))
        .where((item) => item.title.trim().isNotEmpty && item.title != 'Unknown')
        .toList();
  }
}
