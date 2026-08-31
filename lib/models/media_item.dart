class MediaItem {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String mediaType; 
  final String releaseYear;

  MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    required this.mediaType,
    required this.releaseYear,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final type = json['media_type'] ?? (json['first_air_date'] != null ? 'tv' : 'movie');
    final title = json['title'] ?? json['name'] ?? 'Unknown';
    final date = json['release_date'] ?? json['first_air_date'] ?? '';
    final year = date.toString().length >= 4 ? date.toString().substring(0, 4) : 'N/A';
    
    return MediaItem(
      id: json['id'],
      title: title,
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      mediaType: type,
      releaseYear: year,
    );
  }
}
