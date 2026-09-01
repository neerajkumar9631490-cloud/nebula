import 'dart:async';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();

  LibtorrentFlutter? _session;
  String? _currentInfoHash;
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  bool _isStreaming = false;

  Future<void> initialize() async {
    if (_session == null) {
      _session = LibtorrentFlutter();
      await _session!.init(
        savePath: '/sdcard/Android/data/com.nebula.nebula/cache/torrents',
        enableHttpServer: true, // Built-in HTTP server for streaming
        httpPort: 0, // Auto-assign port
      );
    }
  }

  Future<String?> startStream({
    required String magnet,
    int fileIndex = 0,
    Function(double)? onProgress,
  }) async {
    try {
      await initialize();
      
      // Extract info hash from magnet
      final infoHashMatch = RegExp(r'xt=urn:btih:([a-fA-F0-9]{40})').firstMatch(magnet);
      if (infoHashMatch == null) return null;
      final infoHash = infoHashMatch.group(1)!;
      
      _currentInfoHash = infoHash;
      
      // Add torrent to session
      final result = await _session!.addTorrent(
        magnetUri: magnet,
        sequentialDownload: true,
        prioritizeFirstLastPiece: true,
      );
      
      if (!result) return null;
      
      // Listen for progress
      _session!.onTorrentProgress.listen((progress) {
        if (progress.infoHash == infoHash) {
          _progressController.add(progress.progress);
          onProgress?.call(progress.progress);
        }
      });
      
      // Wait for HTTP URL to be ready (streaming server)
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final url = await _session!.getHttpUrl(infoHash, fileIndex);
        if (url != null && url.isNotEmpty) {
          _isStreaming = true;
          return url; // Returns http://127.0.0.1:PORT/path/to/file
        }
      }
      
      return null;
    } catch (e) {
      print('Torrent error: $e');
      return null;
    }
  }

  Future<void> stopStream() async {
    if (_session != null && _isStreaming && _currentInfoHash != null) {
      await _session!.removeTorrent(_currentInfoHash!);
      _isStreaming = false;
      _currentInfoHash = null;
    }
  }

  Stream<double> get progressStream => _progressController.stream;

  void dispose() {
    stopStream();
    _progressController.close();
    _session?.dispose();
  }
}
