import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferred music audio source, mirroring PlayTorrio's
/// `MusicAudioSource.flac / .youtube` switch.
enum MusicAudioSource { flac, youtube }

/// Persisted music playback preferences (audio source + quality badge).
/// PlayTorrio ships a large appearance studio; Nebula keeps the
/// playback-meaningful subset here so settings UI stays small while the
/// player still gets FLAC/YouTube switching and lossless badges.
class MusicSettings extends ChangeNotifier {
  static final MusicSettings instance = MusicSettings._internal();
  MusicSettings._internal();

  static const _sourceKey = 'music_audio_source';
  static const _losslessBadgeKey = 'music_show_lossless_badge';

  MusicAudioSource _source = MusicAudioSource.flac;
  bool _showLosslessBadge = true;
  bool _loaded = false;

  MusicAudioSource get source => _source;
  bool get showLosslessBadge => _showLosslessBadge;
  bool get isFlacPreferred => _source == MusicAudioSource.flac;

  String get qualityLabel =>
      _source == MusicAudioSource.flac ? 'FLAC Hi-Res' : 'YouTube HQ';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_sourceKey);
      _source =
          saved == 'youtube' ? MusicAudioSource.youtube : MusicAudioSource.flac;
      _showLosslessBadge = prefs.getBool(_losslessBadgeKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSource(MusicAudioSource source) async {
    if (_source == source) return;
    _source = source;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _sourceKey, source == MusicAudioSource.flac ? 'flac' : 'youtube');
    } catch (_) {}
  }

  Future<void> setShowLosslessBadge(bool value) async {
    _showLosslessBadge = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_losslessBadgeKey, value);
    } catch (_) {}
  }
}
