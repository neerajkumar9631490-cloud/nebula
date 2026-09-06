/// A movie or series entry sourced from a Stremio catalog plugin
/// (e.g. Cinemeta). Image fields hold full remote URLs — no API key needed.
class MediaItem {
  /// Stremio id, e.g. 'tt0111161'. Used for streams, meta and progress keys.
  final String id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;

  /// 'movie' | 'tv' (Stremio 'series' is normalized to 'tv').
  final String mediaType;
  final String releaseYear;
  final double rating;

  MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.mediaType,
    required this.releaseYear,
    this.rating = 0,
  });

  /// Parses a Stremio Cinemeta-style meta preview object.
  /// [stremioType] is the catalog type: 'movie' or 'series'.
  factory MediaItem.fromCinemeta(Map<String, dynamic> json, String stremioType) {
    final type = stremioType == 'series' ? 'tv' : 'movie';
    final title = json['name']?.toString() ?? 'Unknown';

    final release = json['releaseInfo']?.toString() ?? '';
    final year = release.length >= 4 && _startsWithYear(release)
        ? release.substring(0, 4)
        : '';

    double rating = 0;
    final rawRating = json['imdbRating'];
    if (rawRating is num) {
      rating = rawRating.toDouble();
    } else if (rawRating is String) {
      rating = double.tryParse(rawRating) ?? 0;
    }

    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: title,
      overview: json['description']?.toString() ?? '',
      posterPath: _url(json['poster']),
      backdropPath: _url(json['background']),
      mediaType: type,
      releaseYear: year,
      rating: rating,
    );
  }

  static bool _startsWithYear(String s) {
    if (s.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      final c = s.codeUnitAt(i);
      if (c < 48 || c > 57) return false;
    }
    return true;
  }

  static String? _url(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
