/// A subtitle track advertised alongside a stream
/// (parsed from the provider's `subtitles` array).
class SubtitleTrack {
  final String id;
  final String url;
  final String lang;

  const SubtitleTrack({
    required this.id,
    required this.url,
    this.lang = '',
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    final url = json['url']?.toString() ?? '';
    return SubtitleTrack(
      id: json['id']?.toString() ?? url,
      url: url,
      lang: json['lang']?.toString() ?? '',
    );
  }
}
