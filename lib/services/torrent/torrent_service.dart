import 'dart:async';
import 'dart:io';
import 'package:flutter_torrent_streamer/flutter_torrent_streamer.dart';

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();

  FlutterTorrentStreamer? _streamer;
  String? _currentMagnet;
  StreamController<String>? _progressController;
  bool _isStreaming = false;

  Future<void> initialize() async {
    if (_streamer == null) {
      _streamer = FlutterTorrentStreamer();
      await _streamer!.init();
    }
  }

  Future<String?> startStream({
    required String magnet,
    required int fileIndex,
    Function(double)? onProgress,
  }) async {
    try {
      await initialize();

      _currentMagnet = magnet;
      _progressController = StreamController<String>.broadcast();

      // Listen to progress
      _streamer!.onTorrentStatus.listen((status) {
        if (onProgress != null) {
          onProgress(status.progress);
        }
        _progressController?.add('${status.downloaded}/${status.total}');
      });

      // Start streaming
      final result = await _streamer!.startTorrent(
        magnetLink: magnet,
        savePath: '/sdcard/Android/data/com.nebula.nebula/cache/torrents',
        sequentialDownload: true,
        selectedFiles: [fileIndex],
      );

      if (result.isSuccess && result.localUrl != null) {
        _isStreaming = true;
        return result.localUrl; // Returns local HTTP URL like http://127.0.0.1:PORT/file.mp4
      }

      return null;
    } catch (e) {
      print('Torrent error: $e');
      return null;
    }
  }

  Future<void> stopStream() async {
    if (_streamer != null && _isStreaming) {
      await _streamer!.stopTorrent(_currentMagnet ?? '');
      _isStreaming = false;
      _currentMagnet = null;
      _progressController?.close();
    }
  }

  Stream<String> get progressStream => _progressController?.stream ?? Stream.empty();

  void dispose() {
    stopStream();
    _streamer?.dispose();
    _progressController?.close();
  }
}
