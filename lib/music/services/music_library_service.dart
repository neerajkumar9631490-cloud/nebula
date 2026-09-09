import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';

/// Local music library: likes, user playlists, recently played and
/// play history. Persisted with SharedPreferences (the project's
/// existing storage) — metadata only, never audio files.
class MusicLibraryService {
  static final MusicLibraryService _instance =
      MusicLibraryService._internal();
  factory MusicLibraryService() => _instance;
  MusicLibraryService._internal();

  static const _likesKey = 'music_likes';
  static const _recentKey = 'music_recent';
  static const _historyKey = 'music_history';
  static const _playlistsKey = 'music_playlists';

  // ── Likes ────────────────────────────────────────────────
  Future<Map<String, Track>> likedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_likesKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k, Track.fromJson((v as Map).cast<String, dynamic>())));
    } catch (_) {
      return {};
    }
  }

  Future<bool> isLiked(String trackId) async {
    final liked = await likedTracks();
    return liked.containsKey(trackId);
  }

  /// Returns the new liked state.
  Future<bool> toggleLike(Track track) async {
    final prefs = await SharedPreferences.getInstance();
    final liked = await likedTracks();
    bool nowLiked;
    if (liked.containsKey(track.id)) {
      liked.remove(track.id);
      nowLiked = false;
    } else {
      liked[track.id] = track;
      nowLiked = true;
    }
    await prefs.setString(_likesKey,
        jsonEncode(liked.map((k, v) => MapEntry(k, v.toJson()))));
    return nowLiked;
  }

  // ── Recently played + history ────────────────────────────
  Future<void> recordPlay(Track track) async {
    final prefs = await SharedPreferences.getInstance();
    await _prependCapped(prefs, _recentKey, track.toJson(), 30);
    await _prependCapped(prefs, _historyKey, {
      ...track.toJson(),
      'playedAt': DateTime.now().millisecondsSinceEpoch,
    }, 100);
  }

  Future<List<Track>> recentPlayed({int limit = 15}) async {
    final items = await _readList(_recentKey);
    return items
        .map((j) {
          try {
            return Track.fromJson(j);
          } catch (_) {
            return null;
          }
        })
        .whereType<Track>()
        .take(limit)
        .toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_recentKey);
  }

  // ── Playlists (local, user-created) ──────────────────────
  Future<List<Playlist>> playlists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playlistsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return Playlist(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? 'Playlist',
          tracks: ((m['tracks'] as List?) ?? [])
              .whereType<Map>()
              .map((t) {
            try {
              return Track.fromJson(t.cast<String, dynamic>());
            } catch (_) {
              return null;
            }
          }).whereType<Track>().toList(),
          updatedMs: (m['updated'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await playlists();
    final pl = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'My playlist' : name.trim(),
      updatedMs: DateTime.now().millisecondsSinceEpoch,
    );
    all.insert(0, pl);
    await _savePlaylists(prefs, all);
    return pl;
  }

  Future<void> deletePlaylist(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await playlists())..removeWhere((p) => p.id == id);
    await _savePlaylists(prefs, all);
  }

  Future<void> addToPlaylist(String playlistId, Track track) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await playlists();
    final i = all.indexWhere((p) => p.id == playlistId);
    if (i < 0) return;
    final tracks = List<Track>.from(all[i].tracks);
    if (tracks.any((t) => t.id == track.id)) return;
    tracks.add(track);
    all[i] = all[i].copyWith(
        tracks: tracks, updatedMs: DateTime.now().millisecondsSinceEpoch);
    await _savePlaylists(prefs, all);
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await playlists();
    final i = all.indexWhere((p) => p.id == playlistId);
    if (i < 0) return;
    final tracks =
        List<Track>.from(all[i].tracks)..removeWhere((t) => t.id == trackId);
    all[i] = all[i].copyWith(
        tracks: tracks, updatedMs: DateTime.now().millisecondsSinceEpoch);
    await _savePlaylists(prefs, all);
  }

  // ── Internals ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _prependCapped(SharedPreferences prefs, String key,
      Map<String, dynamic> entry, int cap) async {
    final list = await _readList(key);
    list.removeWhere((e) => e['id']?.toString() == entry['id']?.toString());
    list.insert(0, entry);
    await prefs.setString(key, jsonEncode(list.take(cap).toList()));
  }

  Future<void> _savePlaylists(
      SharedPreferences prefs, List<Playlist> all) async {
    await prefs.setString(
        _playlistsKey,
        jsonEncode(all
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'updated': p.updatedMs,
                  'tracks': p.tracks.map((t) => t.toJson()).toList(),
                })
            .toList()));
  }
}
