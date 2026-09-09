import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import 'lossless_audio_service.dart';
import 'music_settings.dart';
import 'youtube_stream_http.dart';
import 'youtube_stream_resolver.dart';

/// Offline music downloads, ported from PlayTorrio's
/// `MusicDownloadService`: sequential queue, FLAC -> YouTube stream
/// extraction, atomic file writes, cover cache, SharedPreferences index.
/// Storage root is `Movix/Music` (PlayTorrio uses `PlayTorrio/Music`).
enum MusicDownloadStatus {
  queued,
  extracting,
  downloading,
  completed,
  failed,
  cancelled,
}

class MusicDownloadTask {
  final String id;
  final Track track;
  final String? collectionName;
  MusicDownloadStatus status;
  double progress;
  String? format;
  String? quality;
  String? errorMessage;
  int bytesDownloaded;
  int totalBytes;

  MusicDownloadTask({
    required this.id,
    required this.track,
    this.collectionName,
    this.status = MusicDownloadStatus.queued,
    this.progress = 0.0,
    this.format,
    this.quality,
    this.errorMessage,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
  });
}

class DownloadedTrack {
  final Track track;
  final String localAudioPath;
  final String localCoverPath;
  final String format;
  final String quality;
  final int fileSizeBytes;
  final String downloadedAt;

  const DownloadedTrack({
    required this.track,
    required this.localAudioPath,
    required this.localCoverPath,
    required this.format,
    required this.quality,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'audio': localAudioPath,
        'cover': localCoverPath,
        'format': format,
        'quality': quality,
        'size': fileSizeBytes,
        'at': downloadedAt,
      };

  factory DownloadedTrack.fromJson(Map<String, dynamic> j) =>
      DownloadedTrack(
        track: Track.fromJson(
            (j['track'] as Map?)?.cast<String, dynamic>() ?? const {}),
        localAudioPath: j['audio']?.toString() ?? '',
        localCoverPath: j['cover']?.toString() ?? '',
        format: j['format']?.toString() ?? 'm4a',
        quality: j['quality']?.toString() ?? 'HQ Audio',
        fileSizeBytes: (j['size'] as num?)?.toInt() ?? 0,
        downloadedAt: j['at']?.toString() ?? '',
      );
}

class MusicDownloadService extends ChangeNotifier {
  static final MusicDownloadService instance =
      MusicDownloadService._internal();
  MusicDownloadService._internal();

  static const String _storageKey = 'music_downloaded_tracks_v1';

  final List<DownloadedTrack> _downloaded = [];
  final List<MusicDownloadTask> _queue = [];
  bool _isProcessing = false;
  bool _initialized = false;

  Directory? _tracksDir;
  Directory? _coversDir;

  List<DownloadedTrack> get downloadedTracks =>
      List.unmodifiable(_downloaded);
  List<MusicDownloadTask> get queue => List.unmodifiable(_queue);
  bool get isProcessing => _isProcessing;

  int get totalDownloadedSizeBytes =>
      _downloaded.fold<int>(0, (sum, t) => sum + t.fileSizeBytes);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory(p.join(appDocDir.path, 'Movix', 'Music'));
      _tracksDir = Directory(p.join(musicDir.path, 'Tracks'));
      _coversDir = Directory(p.join(musicDir.path, 'Covers'));
      if (!await _tracksDir!.exists()) {
        await _tracksDir!.create(recursive: true);
      }
      if (!await _coversDir!.exists()) {
        await _coversDir!.create(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _downloaded.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            try {
              final rec = DownloadedTrack.fromJson(item);
              final f = File(rec.localAudioPath);
              if (f.existsSync() && f.lengthSync() > 100) {
                _downloaded.add(rec);
              }
            } catch (_) {}
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicDownload] init error: $e');
    }
  }

  bool isDownloaded(String trackId) =>
      _downloaded.any((t) => t.track.id == trackId);

  DownloadedTrack? getDownloadedTrack(String trackId) {
    try {
      return _downloaded.firstWhere((t) => t.track.id == trackId);
    } catch (_) {
      return null;
    }
  }

  File? getDownloadedTrackFile(String trackId) {
    final rec = getDownloadedTrack(trackId);
    if (rec == null) return null;
    final f = File(rec.localAudioPath);
    return f.existsSync() ? f : null;
  }

  bool isQueued(String trackId) => _queue.any((task) =>
      task.track.id == trackId &&
      (task.status == MusicDownloadStatus.queued ||
          task.status == MusicDownloadStatus.extracting ||
          task.status == MusicDownloadStatus.downloading));

  MusicDownloadTask? getTask(String trackId) {
    try {
      return _queue.firstWhere((t) => t.track.id == trackId);
    } catch (_) {
      return null;
    }
  }

  void queueTrack(Track track, {String? collectionName}) {
    if (isDownloaded(track.id) || isQueued(track.id)) return;
    _queue.add(MusicDownloadTask(
      id: '${track.id}_${DateTime.now().millisecondsSinceEpoch}',
      track: track,
      collectionName: collectionName,
    ));
    notifyListeners();
    _processQueue();
  }

  void queueTracks(List<Track> tracks, {String? collectionName}) {
    var added = false;
    for (final track in tracks) {
      if (isDownloaded(track.id) || isQueued(track.id)) continue;
      _queue.add(MusicDownloadTask(
        id: '${track.id}_${DateTime.now().millisecondsSinceEpoch}',
        track: track,
        collectionName: collectionName,
      ));
      added = true;
    }
    if (added) {
      notifyListeners();
      _processQueue();
    }
  }

  void cancelTask(String trackId) {
    final task = getTask(trackId);
    if (task != null) {
      task.status = MusicDownloadStatus.cancelled;
      _queue.removeWhere((t) => t.track.id == trackId);
      notifyListeners();
    }
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    final rec = getDownloadedTrack(trackId);
    if (rec == null) return;
    try {
      final audio = File(rec.localAudioPath);
      if (await audio.exists()) await audio.delete();
      if (rec.localCoverPath.isNotEmpty) {
        final cover = File(rec.localCoverPath);
        if (await cover.exists()) await cover.delete();
      }
    } catch (e) {
      debugPrint('[MusicDownload] delete error: $e');
    }
    _downloaded.removeWhere((t) => t.track.id == trackId);
    await _save();
    notifyListeners();
  }

  void clearCompletedTasks() {
    _queue.removeWhere((t) =>
        t.status == MusicDownloadStatus.completed ||
        t.status == MusicDownloadStatus.failed ||
        t.status == MusicDownloadStatus.cancelled);
    notifyListeners();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await init();
      while (true) {
        MusicDownloadTask? next;
        for (final task in _queue) {
          if (task.status == MusicDownloadStatus.queued) {
            next = task;
            break;
          }
        }
        if (next == null) break;
        await _execute(next);
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _execute(MusicDownloadTask task) async {
    final track = task.track;
    task.status = MusicDownloadStatus.extracting;
    task.progress = 0.05;
    notifyListeners();

    String? streamUrl;
    Map<String, String> headers = {};
    var format = 'm4a';
    var quality = 'HQ Audio';

    try {
      if (MusicSettings.instance.source == MusicAudioSource.flac) {
        try {
          final flac =
              await LosslessAudioService.instance.resolveLosslessUrl(track);
          if (flac != null && flac.url.isNotEmpty) {
            streamUrl = flac.url;
            format = flac.format;
            quality = flac.quality;
            if (flac.headers['User-Agent'] != null) {
              headers['User-Agent'] = flac.headers['User-Agent']!;
            }
          }
        } catch (e) {
          debugPrint('[MusicDownload] FLAC failed, YouTube next: $e');
        }
      }
      if (streamUrl == null || streamUrl.isEmpty) {
        final yt = await YoutubeStreamResolver.instance.resolveUrl(track);
        if (yt != null && yt.url.isNotEmpty) {
          streamUrl = yt.url;
          format = 'm4a';
          quality = 'YouTube HQ';
          headers = YoutubeStreamHttp.streamHeaders(yt.url,
              userAgent: yt.userAgent);
        }
      }
    } catch (e) {
      debugPrint('[MusicDownload] resolve failed ${track.title}: $e');
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      task.status = MusicDownloadStatus.failed;
      task.errorMessage = 'Could not find a valid audio stream.';
      notifyListeners();
      return;
    }

    task.format = format;
    task.quality = quality;
    task.status = MusicDownloadStatus.downloading;
    task.progress = 0.1;
    notifyListeners();

    var localCoverPath = '';
    final coverUrl = track.artworkLarge.isNotEmpty
        ? track.artworkLarge
        : track.artworkSmall;
    if (coverUrl.isNotEmpty) {
      try {
        final safeId = _sanitize(track.id);
        final coverFile = File(p.join(_coversDir!.path, '$safeId.jpg'));
        if (await coverFile.exists() && await coverFile.length() > 100) {
          localCoverPath = coverFile.path;
        } else {
          final client = HttpClient();
          final req = await client.getUrl(Uri.parse(coverUrl));
          final res = await req.close();
          if (res.statusCode == 200) {
            final bytes = await consolidateHttpClientResponseBytes(res);
            if (bytes.isNotEmpty) {
              await coverFile.writeAsBytes(bytes);
              localCoverPath = coverFile.path;
            }
          }
          client.close();
        }
      } catch (e) {
        debugPrint('[MusicDownload] cover warning: $e');
      }
    }

    final safeId = _sanitize(track.id);
    final target = File(p.join(_tracksDir!.path, '$safeId.$format'));
    final tmp = File(p.join(_tracksDir!.path, '$safeId.$format.tmp'));

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamUrl));
      headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final contentLength = response.contentLength;
      task.totalBytes = contentLength > 0 ? contentLength : 0;
      if (await tmp.exists()) await tmp.delete();
      final sink = tmp.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (task.status == MusicDownloadStatus.cancelled) {
          await sink.close();
          if (await tmp.exists()) await tmp.delete();
          client.close();
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        task.bytesDownloaded = received;
        if (contentLength > 0) {
          task.progress = 0.1 + (0.88 * (received / contentLength));
        }
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      client.close();
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);

      _downloaded.removeWhere((t) => t.track.id == track.id);
      _downloaded.insert(
          0,
          DownloadedTrack(
            track: track,
            localAudioPath: target.path,
            localCoverPath: localCoverPath,
            format: format,
            quality: quality,
            fileSizeBytes: await target.length(),
            downloadedAt: DateTime.now().toIso8601String(),
          ));
      await _save();
      task.status = MusicDownloadStatus.completed;
      task.progress = 1.0;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicDownload] failed ${track.title}: $e');
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      task.status = MusicDownloadStatus.failed;
      task.errorMessage = 'Download error: $e';
      notifyListeners();
    }
  }

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey,
          jsonEncode(_downloaded.map((t) => t.toJson()).toList()));
    } catch (e) {
      debugPrint('[MusicDownload] save error: $e');
    }
  }
}
