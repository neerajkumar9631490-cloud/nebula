import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WatchProgress {
  final int positionMs;
  final int durationMs;
  final int timestampMs; // when saved
  final String? title;

  const WatchProgress({
    required this.positionMs,
    required this.durationMs,
    required this.timestampMs,
    this.title,
  });

  double get progressPercent =>
      durationMs > 0 ? (positionMs / durationMs) * 100 : 0;

  bool get isResumable {
    // Resume if watched between 3% and 90%
    return progressPercent >= 3 && progressPercent <= 90;
  }

  String get positionLabel {
    final pos = Duration(milliseconds: positionMs);
    final dur = Duration(milliseconds: durationMs);
    return '${_fmt(pos)} / ${_fmt(dur)}';
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'p': positionMs,
        'd': durationMs,
        't': timestampMs,
        if (title != null) 'n': title,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        positionMs: j['p'] as int? ?? 0,
        durationMs: j['d'] as int? ?? 0,
        timestampMs: j['t'] as int? ?? 0,
        title: j['n'] as String?,
      );
}

class WatchProgressService {
  static final WatchProgressService _instance = WatchProgressService._internal();
  factory WatchProgressService() => _instance;
  WatchProgressService._internal();

  static String _keyMovie(int id) => 'wp_movie_$id';
  static String _keyEpisode(int id, int season, int episode) =>
      'wp_tv_${id}_s${season}_e$episode';

  Future<void> saveMovie({
    required int id,
    required int positionMs,
    required int durationMs,
    String? title,
  }) async {
    await _save(_keyMovie(id), positionMs, durationMs, title);
  }

  Future<void> saveEpisode({
    required int id,
    required int season,
    required int episode,
    required int positionMs,
    required int durationMs,
    String? title,
  }) async {
    await _save(
      _keyEpisode(id, season, episode),
      positionMs,
      durationMs,
      title,
    );
  }

  Future<void> _save(
      String key, int positionMs, int durationMs, String? title) async {
    if (positionMs < 0 || durationMs <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final data = WatchProgress(
      positionMs: positionMs,
      durationMs: durationMs,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      title: title,
    ).toJson();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<WatchProgress?> loadMovie(int id) async {
    return _load(_keyMovie(id));
  }

  Future<WatchProgress?> loadEpisode(
      int id, int season, int episode) async {
    return _load(_keyEpisode(id, season, episode));
  }

  Future<WatchProgress?> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return WatchProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearMovie(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMovie(id));
  }

  Future<void> clearEpisode(int id, int season, int episode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEpisode(id, season, episode));
  }
}
