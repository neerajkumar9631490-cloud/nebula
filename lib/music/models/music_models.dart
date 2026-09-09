/// Clean music domain models. UI and player code depend only on these —
/// never on provider-specific JSON.
class Track {
  final String id; // '<source>:<remoteId>', e.g. 'deezer:123'
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String artworkSmall; // list rows
  final String artworkLarge; // full player
  final int durationMs;
  final String source; // 'itunes' | 'deezer'
  final String audioUrl; // streamable preview URL (see resolver)
  final String quality; // e.g. 'Preview'
  final bool explicit;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId = '',
    this.album = '',
    this.albumId = '',
    this.artworkSmall = '',
    this.artworkLarge = '',
    this.durationMs = 0,
    required this.source,
    this.audioUrl = '',
    this.quality = 'Preview',
    this.explicit = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artistId': artistId,
        'album': album,
        'albumId': albumId,
        'artSmall': artworkSmall,
        'artLarge': artworkLarge,
        'dur': durationMs,
        'source': source,
        'audio': audioUrl,
        'quality': quality,
        'explicit': explicit,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Unknown track',
        artist: j['artist']?.toString() ?? 'Unknown artist',
        artistId: j['artistId']?.toString() ?? '',
        album: j['album']?.toString() ?? '',
        albumId: j['albumId']?.toString() ?? '',
        artworkSmall: j['artSmall']?.toString() ?? '',
        artworkLarge: j['artLarge']?.toString() ?? '',
        durationMs: (j['dur'] as num?)?.toInt() ?? 0,
        source: j['source']?.toString() ?? '',
        audioUrl: j['audio']?.toString() ?? '',
        quality: j['quality']?.toString() ?? 'Preview',
        explicit: j['explicit'] == true,
      );
}

class Artist {
  final String id;
  final String name;
  final String artwork;
  final String source;

  const Artist({
    required this.id,
    required this.name,
    this.artwork = '',
    required this.source,
  });
}

class Album {
  final String id;
  final String title;
  final String artist;
  final String artwork;
  final String source;

  const Album({
    required this.id,
    required this.title,
    this.artist = '',
    this.artwork = '',
    required this.source,
  });
}

class Playlist {
  final String id;
  final String name;
  final List<Track> tracks;
  final int updatedMs;

  const Playlist({
    required this.id,
    required this.name,
    this.tracks = const [],
    this.updatedMs = 0,
  });

  Playlist copyWith({String? name, List<Track>? tracks, int? updatedMs}) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        updatedMs: updatedMs ?? this.updatedMs,
      );
}

/// A resolved, playable audio stream. Produced only by an
/// [AudioSourceResolver]; the player opens [url] and nothing else.
class AudioSource {
  final String url;
  final String quality;
  final String mime;

  const AudioSource({
    required this.url,
    this.quality = 'Preview',
    this.mime = 'audio/mpeg',
  });
}

/// One entry in the playback queue. Wraps a [Track] with a unique
/// [queueId] so the same track can appear multiple times.
class QueueItem {
  final Track track;
  final String queueId;
  final int addedMs;

  QueueItem({
    required this.track,
    String? queueId,
    int? addedMs,
  })  : queueId = queueId ??
            '${DateTime.now().microsecondsSinceEpoch}_${track.id}',
        addedMs = addedMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'q': queueId,
        'a': addedMs,
        't': track.toJson(),
      };

  factory QueueItem.fromJson(Map<String, dynamic> j) => QueueItem(
        queueId: j['q']?.toString(),
        addedMs: (j['a'] as num?)?.toInt(),
        track: Track.fromJson(
            (j['t'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}
