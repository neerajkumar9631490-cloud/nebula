import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:torrserver_flutter/torrserver_flutter.dart';

class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final double progress;
  final bool isReady;

  const TorrentStats({
    required this.speedMbps,
    required this.activePeers,
    required this.progress,
    required this.isReady,
  });

  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(2)} MB/s'
      : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';
}

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();

  final TorrServerController _controller = createTorrServerController();
  final Set<String> _activeTorrents = {};
  final Map<String, TorrentInfo> _latestUpdates = {};

  bool _isInitialized = false;
  bool _isStarting = false;

  /// Initialize TorrServer engine
  Future<bool> initialize() async {
    if (_isInitialized && _controller.isRunning) return true;
    if (_isStarting) {
      // Wait for startup to complete
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isInitialized && _controller.isRunning) return true;
      }
      return false;
    }

    _isStarting = true;
    try {
      debugPrint('[Torrent] Starting TorrServer engine...');
      await _controller.start();
      final version = await _controller.echo();
      _isInitialized = true;
      _isStarting = false;
      debugPrint('[Torrent] TorrServer ready at ${_controller.baseUrl} (v$version)');
      return true;
    } catch (e) {
      debugPrint('[Torrent] Failed to start TorrServer: $e');
      _isStarting = false;
      return false;
    }
  }

  /// Extract info hash from magnet link
  String? _extractHash(String magnet) {
    final match = RegExp(r'[0-9a-fA-F]{40}').firstMatch(magnet);
    return match?.group(0)?.toLowerCase();
  }

  /// Wait for torrent metadata to load
  Future<List<TorrentFileStat>?> _waitForMetadata(
    String hash, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final info = await _controller.getTorrent(hash);
        _latestUpdates[hash] = info;
        if (info.fileStats.isNotEmpty) {
          return info.fileStats;
        }
      } catch (e) {
        debugPrint('[Torrent] Metadata polling error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    debugPrint('[Torrent] Metadata timeout for $hash');
    return null;
  }

  /// Select the best file from torrent (video/audio files only)
  int? _selectFile(List<TorrentFileStat> files, {int? preferredIdx}) {
    if (files.isEmpty) return null;

    // Use preferred index if provided
    if (preferredIdx != null) {
      final match = files.where((f) => f.id == preferredIdx).toList();
      if (match.isNotEmpty) return match.first.id;
    }

    // Filter to media files
    bool isMediaFile(String name) {
      final lower = name.toLowerCase();
      return lower.endsWith('.mp4') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.avi') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.m4b');
    }

    final mediaFiles = files.where((f) => isMediaFile(f.path)).toList();

    if (mediaFiles.isEmpty) {
      // Fallback: largest file
      final sorted = List<TorrentFileStat>.from(files)
        ..sort((a, b) => b.length.compareTo(a.length));
      return sorted.first.id;
    }

    // Return largest media file
    mediaFiles.sort((a, b) => b.length.compareTo(a.length));
    return mediaFiles.first.id;
  }

  /// Start streaming torrent - returns HTTP URL for playback
  Future<String?> startStream({
    required String magnet,
    int? fileIndex,
    Function(TorrentStats)? onStats,
  }) async {
    // Ensure engine is running
    if (!await initialize()) {
      debugPrint('[Torrent] Cannot stream: engine failed to start');
      return null;
    }

    final hash = _extractHash(magnet);
    if (hash == null) {
      debugPrint('[Torrent] Invalid magnet link');
      return null;
    }

    try {
      debugPrint('[Torrent] Adding torrent: $hash');
      final added = await _controller.addTorrent(
        magnet: magnet,
        title: null,
        saveToDb: false,
      );

      final torrentHash = added.hash.isNotEmpty
          ? added.hash.toLowerCase()
          : hash.toLowerCase();

      _activeTorrents.add(torrentHash);
      _latestUpdates[torrentHash] = added;

      debugPrint('[Torrent] Waiting for metadata...');
      final files = await _waitForMetadata(torrentHash);

      if (files == null || files.isEmpty) {
        debugPrint('[Torrent] No files found in torrent');
        return null;
      }

      // Select file to stream
      final fileId = _selectFile(files, preferredIdx: fileIndex);
      if (fileId == null) {
        debugPrint('[Torrent] No suitable media file found');
        return null;
      }

      final selectedFile = files.firstWhere(
        (f) => f.id == fileId,
        orElse: () => files.first,
      );

      debugPrint('[Torrent] Selected file #$fileId: ${selectedFile.path}');

      // Generate HTTP stream URL
      final streamUrl = _controller.streamUrl(torrentHash, fileIndex: fileId);
      debugPrint('[Torrent] Stream URL: $streamUrl');

      // Start stats streaming if callback provided
      if (onStats != null) {
        _streamStats(torrentHash, onStats);
      }

      return streamUrl.toString();
    } catch (e) {
      debugPrint('[Torrent] startStream error: $e');
      return null;
    }
  }

  /// Stream torrent stats
  void _streamStats(String hash, Function(TorrentStats) callback) {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_controller.isRunning) {
        timer.cancel();
        return;
      }

      try {
        final info = await _controller.getTorrent(hash);
        _latestUpdates[hash] = info;

        final total = info.torrentSize;
        final loaded = info.loadedSize;
        final progress = total > 0 ? (loaded / total) : 0.0;
        final speedMbps = info.downloadSpeed / 1024 / 1024;

        callback(TorrentStats(
          speedMbps: speedMbps,
          activePeers: info.activePeers,
          progress: progress,
          isReady: info.activePeers > 0 || info.downloadSpeed > 0,
        ));
      } catch (_) {}
    });
  }

  /// Remove torrent from engine
  Future<void> removeTorrent(String magnetOrHash) async {
    final hash = _extractHash(magnetOrHash) ?? magnetOrHash.toLowerCase();
    _activeTorrents.remove(hash);
    _latestUpdates.remove(hash);

    if (_controller.isRunning) {
      try {
        await _controller.removeTorrent(hash);
        debugPrint('[Torrent] Removed torrent $hash');
      } catch (e) {
        debugPrint('[Torrent] Error removing torrent: $e');
      }
    }
  }

  /// Cleanup all torrents
  Future<void> cleanup() async {
    for (final hash in List<String>.from(_activeTorrents)) {
      await removeTorrent(hash);
    }
    debugPrint('[Torrent] Cleanup completed');
  }

  /// Stop TorrServer engine
  Future<void> stop() async {
    if (_controller.isRunning) {
      try {
        await _controller.stop();
        debugPrint('[Torrent] TorrServer stopped');
      } catch (e) {
        debugPrint('[Torrent] Error stopping: $e');
      }
    }
    _activeTorrents.clear();
    _latestUpdates.clear();
    _isInitialized = false;
  }
}
