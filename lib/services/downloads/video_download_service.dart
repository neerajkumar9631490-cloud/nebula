import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/media_item.dart';
import '../../models/stream_result.dart';
import '../torrent/torrent_service.dart';

/// Offline video downloads. Mirrors [MusicDownloadService]: a sequential
/// queue, atomic file writes, cover reuse from the catalog artwork and
/// a SharedPreferences index — videos live under `Movix/Downloads`.
///
/// Source handling:
/// * direct HTTP files download straight to disk,
/// * torrents/magnets download through the already-running TorrServer
///   engine (its sequential stream endpoint is read to EOF, then the
///   torrent is dropped so playback streams are untouched),
/// * HLS playlists and external links are rejected at queue time —
///   a playlist file alone is not a playable download.
enum VideoDownloadStatus {
  queued,
  preparing,
  downloading,
  completed,
  failed,
  cancelled,
}

class VideoDownloadTask {
  final String id;
  final String videoId;
  final String itemId;
  final String title;
  final String detail;
  final String? posterUrl;
  final String sourceName;
  final StreamKind kind;
  final String? url;
  final String? magnet;
  final int? fileIndex;
  final String mediaType;
  final int season;
  final int episode;
  VideoDownloadStatus status;
  double progress; // 0..1, -1 when size unknown
  String? errorMessage;
  int bytesDownloaded;
  int totalBytes;

  VideoDownloadTask({
    required this.id,
    required this.videoId,
    required this.itemId,
    required this.title,
    required this.detail,
    this.posterUrl,
    required this.sourceName,
    required this.kind,
    this.url,
    this.magnet,
    this.fileIndex,
    required this.mediaType,
    required this.season,
    required this.episode,
    this.status = VideoDownloadStatus.queued,
    this.progress = 0,
    this.errorMessage,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
  });
}

class DownloadedVideo {
  final String videoId;
  final String itemId;
  final String title;
  final String detail;
  final String? posterUrl;
  final String sourceName;
  final String mediaType;
  final int season;
  final int episode;
  final String localPath;
  final int sizeBytes;
  final String downloadedAt;

  const DownloadedVideo({
    required this.videoId,
    required this.itemId,
    required this.title,
    required this.detail,
    this.posterUrl,
    required this.sourceName,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.localPath,
    required this.sizeBytes,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'itemId': itemId,
        'title': title,
        'detail': detail,
        'poster': posterUrl,
        'source': sourceName,
        'mediaType': mediaType,
        'season': season,
        'episode': episode,
        'path': localPath,
        'size': sizeBytes,
        'at': downloadedAt,
      };

  factory DownloadedVideo.fromJson(Map<String, dynamic> j) =>
      DownloadedVideo(
        videoId: j['videoId']?.toString() ?? '',
        itemId: j['itemId']?.toString() ?? j['videoId']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Unknown',
        detail: j['detail']?.toString() ?? '',
        posterUrl: j['poster']?.toString(),
        sourceName: j['source']?.toString() ?? '',
        mediaType: j['mediaType']?.toString() ?? 'movie',
        season: (j['season'] as num?)?.toInt() ?? 1,
        episode: (j['episode'] as num?)?.toInt() ?? 1,
        localPath: j['path']?.toString() ?? '',
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
        downloadedAt: j['at']?.toString() ?? '',
      );
}

class VideoDownloadService extends ChangeNotifier {
  static final VideoDownloadService instance =
      VideoDownloadService._internal();
  VideoDownloadService._internal();

  static const _storageKey = 'movix_downloaded_videos_v1';

  final List<DownloadedVideo> _downloaded = [];
  final List<VideoDownloadTask> _queue = [];
  bool _isProcessing = false;
  bool _initialized = false;

  Directory? _dir;

  List<DownloadedVideo> get downloaded =>
      List.unmodifiable(_downloaded);
  List<VideoDownloadTask> get queue => List.unmodifiable(_queue);
  bool get isProcessing => _isProcessing;

  int get totalSizeBytes =>
      _downloaded.fold<int>(0, (sum, v) => sum + v.sizeBytes);

  List<VideoDownloadTask> get active => _queue
      .where((t) =>
          t.status == VideoDownloadStatus.queued ||
          t.status == VideoDownloadStatus.preparing ||
          t.status == VideoDownloadStatus.downloading)
      .toList();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final appDoc = await getApplicationDocumentsDirectory();
      _dir = Directory(p.join(appDoc.path, 'Movix', 'Downloads', 'Videos'));
      if (!await _dir!.exists()) {
        await _dir!.create(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _downloaded.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            try {
              final rec = DownloadedVideo.fromJson(item);
              final f = File(rec.localPath);
              if (rec.localPath.isNotEmpty &&
                  f.existsSync() &&
                  f.lengthSync() > 1024) {
                _downloaded.add(rec);
              }
            } catch (_) {}
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[VideoDownload] init error: $e');
    }
  }

  static String videoIdFor(String itemId, String mediaType,
      {int season = 1, int episode = 1}) {
    final tv = mediaType == 'tv';
    return tv ? '$itemId|S$season:E$episode' : itemId;
  }

  bool isDownloaded(String videoId) =>
      _downloaded.any((v) => v.videoId == videoId);

  DownloadedVideo? getDownloaded(String videoId) {
    try {
      return _downloaded.firstWhere((v) => v.videoId == videoId);
    } catch (_) {
      return null;
    }
  }

  bool isQueued(String videoId) => _queue.any((t) =>
      t.videoId == videoId &&
      (t.status == VideoDownloadStatus.queued ||
          t.status == VideoDownloadStatus.preparing ||
          t.status == VideoDownloadStatus.downloading));

  /// Queues a download. Returns a message for the UI snackbar:
  /// 'queued', 'already' or a human-readable rejection reason.
  String queueDownload({
    required MediaItem item,
    required StreamResult result,
    int season = 1,
    int episode = 1,
  }) {
    final videoId = videoIdFor(item.id, item.mediaType,
        season: season, episode: episode);
    if (isDownloaded(videoId) || isQueued(videoId)) return 'already';
    if (result.kind == StreamKind.hls) {
      return 'Live (HLS) streams can\u2019t be downloaded — pick a file or torrent source.';
    }
    if (result.kind == StreamKind.external || result.url == null) {
      if (result.kind != StreamKind.torrent) {
        return 'This source can\u2019t be downloaded — pick a file or torrent source.';
      }
    }
    if (result.kind == StreamKind.torrent && result.magnet == null) {
      return 'This torrent has no playable file.';
    }

    final tv = item.mediaType == 'tv';
    _queue.add(VideoDownloadTask(
      id: '${videoId}_${DateTime.now().millisecondsSinceEpoch}',
      videoId: videoId,
      itemId: item.id,
      title: item.title,
      detail: tv ? 'S${season}E$episode • ${result.sourceName}' : result.sourceName,
      posterUrl: item.posterPath ?? item.backdropPath,
      sourceName: result.sourceName,
      kind: result.kind,
      url: result.url,
      magnet: result.magnet,
      fileIndex: result.fileIndex,
      mediaType: item.mediaType,
      season: season,
      episode: episode,
    ));
    notifyListeners();
    _processQueue();
    return 'queued';
  }

  void cancelTask(String taskId) {
    try {
      final task =
          _queue.firstWhere((t) => t.id == taskId);
      task.status = VideoDownloadStatus.cancelled;
    } catch (_) {}
    _queue.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  Future<void> deleteDownload(String videoId) async {
    final rec = getDownloaded(videoId);
    if (rec == null) return;
    try {
      final f = File(rec.localPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[VideoDownload] delete error: $e');
    }
    _downloaded.removeWhere((v) => v.videoId == videoId);
    await _save();
    notifyListeners();
  }

  void clearFinished() {
    _queue.removeWhere((t) =>
        t.status == VideoDownloadStatus.completed ||
        t.status == VideoDownloadStatus.failed ||
        t.status == VideoDownloadStatus.cancelled);
    notifyListeners();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await init();
      while (true) {
        VideoDownloadTask? next;
        for (final t in _queue) {
          if (t.status == VideoDownloadStatus.queued) {
            next = t;
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

  Future<void> _execute(VideoDownloadTask task) async {
    task.status = VideoDownloadStatus.preparing;
    task.progress = 0;
    notifyListeners();

    String? sourceUrl;
    if (task.kind == StreamKind.torrent) {
      try {
        sourceUrl = await TorrentService().startStream(
          magnet: task.magnet!,
          fileIndex: task.fileIndex,
        );
      } catch (e) {
        debugPrint('[VideoDownload] torrent prep failed: $e');
      } finally {
        // The engine torrent is only needed while bytes are read;
        // dropping happens after the file lands (or on failure).
      }
      if (task.status == VideoDownloadStatus.cancelled) {
        await TorrentService().dropTorrent(task.magnet!);
        return;
      }
      if (sourceUrl == null || sourceUrl.isEmpty) {
        task.status = VideoDownloadStatus.failed;
        task.errorMessage = 'Torrent produced no playable file.';
        notifyListeners();
        return;
      }
    } else {
      sourceUrl = task.url;
    }
    if (sourceUrl == null || sourceUrl.isEmpty) {
      task.status = VideoDownloadStatus.failed;
      task.errorMessage = 'No playable URL for this source.';
      notifyListeners();
      return;
    }

    task.status = VideoDownloadStatus.downloading;
    notifyListeners();

    final ext = _extensionFor(sourceUrl);
    final safe = _sanitize('${task.title}_${task.videoId}');
    final target = File(p.join(_dir!.path, '$safe.$ext'));
    final tmp = File(p.join(_dir!.path, '$safe.$ext.tmp'));

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(sourceUrl));
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      task.totalBytes = total > 0 ? total : 0;
      if (await tmp.exists()) await tmp.delete();
      final sink = tmp.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (task.status == VideoDownloadStatus.cancelled) {
          await sink.close();
          if (await tmp.exists()) await tmp.delete();
          client.close();
          if (task.kind == StreamKind.torrent) {
            await TorrentService().dropTorrent(task.magnet!);
          }
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        task.bytesDownloaded = received;
        task.progress = total > 0 ? received / total : -1;
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      client.close();

      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);

      if (task.kind == StreamKind.torrent) {
        await TorrentService().dropTorrent(task.magnet!);
      }

      _downloaded.removeWhere((v) => v.videoId == task.videoId);
      _downloaded.insert(
        0,
        DownloadedVideo(
          videoId: task.videoId,
          itemId: task.itemId,
          title: task.title,
          detail: task.detail,
          posterUrl: task.posterUrl,
          sourceName: task.sourceName,
          mediaType: task.mediaType,
          season: task.season,
          episode: task.episode,
          localPath: target.path,
          sizeBytes: await target.length(),
          downloadedAt: DateTime.now().toIso8601String(),
        ),
      );
      await _save();
      task.status = VideoDownloadStatus.completed;
      task.progress = 1;
      notifyListeners();
    } catch (e) {
      debugPrint('[VideoDownload] failed ${task.title}: $e');
      if (task.kind == StreamKind.torrent && task.magnet != null) {
        try {
          await TorrentService().dropTorrent(task.magnet!);
        } catch (_) {}
      }
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      if (task.status != VideoDownloadStatus.cancelled) {
        task.status = VideoDownloadStatus.failed;
        task.errorMessage = 'Download error: $e';
      }
      notifyListeners();
    }
  }

  String _extensionFor(String url) {
    try {
      final pathSegment =
          Uri.parse(url).path.toLowerCase();
      for (final ext in ['mp4', 'mkv', 'webm', 'avi', 'mov']) {
        if (pathSegment.endsWith('.$ext')) return ext;
      }
    } catch (_) {}
    return 'mp4';
  }

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(
          RegExp(r'\s+'), ' ').trim().replaceAll(' ', '_');

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey,
          jsonEncode(_downloaded.map((v) => v.toJson()).toList()));
    } catch (e) {
      debugPrint('[VideoDownload] save error: $e');
    }
  }
}
