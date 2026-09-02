import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:torrserver_flutter/torrserver_flutter.dart';

class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final double progress;
  final bool isReady;
  const TorrentStats({required this.speedMbps, required this.activePeers, required this.progress, required this.isReady});
  String get speedLabel => speedMbps >= 1.0 ? '${speedMbps.toStringAsFixed(1)} MB/s' : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';
}

enum TorrentPhase { engine, metadata, peers, ready, error }

class TorrentService {
  static final TorrentService _instance = TorrentService._internal();
  factory TorrentService() => _instance;
  TorrentService._internal();
  final TorrServerController _controller = createTorrServerController();
  final Set<String> _active = {};
  bool _isInitialized = false;
  bool _isStarting = false;

  Future<bool> initialize() async {
    if (_isInitialized && _controller.isRunning) return true;
    if (_isStarting) {
      for (int i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isInitialized && _controller.isRunning) return true;
      }
      return false;
    }
    _isStarting = true;
    try {
      await _controller.start();
      await _controller.echo();
      _isInitialized = true;
      _isStarting = false;
      return true;
    } catch (e) {
      _isStarting = false;
      try {
        await Future.delayed(const Duration(milliseconds: 800));
        await _controller.start();
        await _controller.echo();
        _isInitialized = true;
        return true;
      } catch (_) { return false; }
    }
  }

  String? _extractHash(String magnet) => RegExp(r'[0-9a-fA-F]{40}').firstMatch(magnet)?.group(0)?.toLowerCase();

  Future<List<TorrentFileStat>?> _waitForMetadata(String hash) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < const Duration(seconds: 45)) {
      try {
        final info = await _controller.getTorrent(hash);
        if (info.fileStats.isNotEmpty) return info.fileStats;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  int? _selectFile(List<TorrentFileStat> files, {int? preferredIdx}) {
    if (files.isEmpty) return null;
    if (preferredIdx != null) {
      final m = files.where((f) => f.id == preferredIdx).toList();
      if (m.isNotEmpty) return m.first.id;
    }
    final media = files.where((f) => f.path.toLowerCase().endsWith('.mp4') || f.path.toLowerCase().endsWith('.mkv')).toList();
    final pool = media.isEmpty ? files : media;
    final sorted = List<TorrentFileStat>.from(pool)..sort((a, b) => b.length.compareTo(a.length));
    return sorted.first.id;
  }

  Future<String?> startStream({required String magnet, int? fileIndex, void Function(TorrentPhase, TorrentStats?)? onPhase}) async {
    onPhase?.call(TorrentPhase.engine, null);
    if (!await initialize()) { onPhase?.call(TorrentPhase.error, null); return null; }
    final hash = _extractHash(magnet);
    if (hash == null) { onPhase?.call(TorrentPhase.error, null); return null; }
    try {
      onPhase?.call(TorrentPhase.metadata, null);
      final added = await _controller.addTorrent(magnet: magnet, title: null, saveToDb: false);
      final th = added.hash.isNotEmpty ? added.hash.toLowerCase() : hash;
      _active.add(th);
      final files = await _waitForMetadata(th);
      if (files == null || files.isEmpty) { onPhase?.call(TorrentPhase.error, null); return null; }
      final fileId = _selectFile(files, preferredIdx: fileIndex);
      if (fileId == null) { onPhase?.call(TorrentPhase.error, null); return null; }
      const minBytes = 2 * 1024 * 1024;
      final sw = Stopwatch()..start();
      while (sw.elapsed < const Duration(seconds: 30)) {
        try {
          final info = await _controller.getTorrent(th);
          final stats = TorrentStats(speedMbps: info.downloadSpeed / 1024 / 1024, activePeers: info.activePeers, progress: info.torrentSize > 0 ? info.loadedSize / info.torrentSize : 0, isReady: info.loadedSize > 0);
          onPhase?.call(TorrentPhase.peers, stats);
          if (info.loadedSize >= minBytes) break;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 400));
      }
      onPhase?.call(TorrentPhase.ready, null);
      return _controller.streamUrl(th, fileIndex: fileId).toString();
    } catch (e) {
      onPhase?.call(TorrentPhase.error, null);
      return null;
    }
  }

  Stream<TorrentStats> statsStream(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash) ?? magnetOrHash.toLowerCase();
    final c = StreamController<TorrentStats>();
    Timer? t;
    c.onListen = () {
      t = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final info = await _controller.getTorrent(hash);
          c.add(TorrentStats(speedMbps: info.downloadSpeed / 1024 / 1024, activePeers: info.activePeers, progress: info.torrentSize > 0 ? info.loadedSize / info.torrentSize : 0, isReady: info.activePeers > 0));
        } catch (_) {}
      });
    };
    c.onCancel = () { t?.cancel(); c.close(); };
    return c.stream;
  }

  Future<void> cleanup() async {
    for (final h in List<String>.from(_active)) {
      try { if (_controller.isRunning) await _controller.dropTorrent(h); } catch (_) {}
      _active.remove(h);
    }
  }
}
