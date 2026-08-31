import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class TMDBService {
  final String apiKey;
  TMDBService(this.apiKey);
  
  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _imgUrl = 'https://image.tmdb.org/t/p/w500';

  String getImgUrl(String? path) => path != null ? '$_imgUrl$path' : '';

  Future<bool> validateKey() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/trending/all/week?api_key=$apiKey'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<MediaItem>> getTrending() async {
    final res = await http.get(Uri.parse('$_baseUrl/trending/all/week?api_key=$apiKey'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return (data['results'] as List).map((e) => MediaItem.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<MediaItem>> search(String query) async {
    if (query.isEmpty) return [];
    final res = await http.get(Uri.parse('$_baseUrl/search/multi?api_key=$apiKey&query=${Uri.encodeComponent(query)}'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return (data['results'] as List)
          .where((e) => e['media_type'] != 'person')
          .map((e) => MediaItem.fromJson(e))
          .toList();
    }
    return [];
  }
}
