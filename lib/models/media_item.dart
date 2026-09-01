class MediaItem {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
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

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final type = json['media_type'] ?? (json['first_air_date'] != null ? 'tv' : 'movie');
    final title = json['title'] ?? json['name'] ?? 'Unknown';
    final date = json['release_date'] ?? json['first_air_date'] ?? '';
    final year = date.toString().length >= 4 ? date.toString().substring(0, 4) : 'N/A';
    final vote = (json['vote_average'] is num) ? (json['vote_average'] as num).toDouble() : 0.0;

    return MediaItem(
      id: json['id'] as int? ?? 0,
      title: title.toString(),
      overview: json['overview']?.toString() ?? '',
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      mediaType: type.toString(),
      releaseYear: year,
      rating: vote,
    );
  }
}
