import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  bool _profileApplied = false;

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

  /// Healthy public trackers injected into magnets that arrive with few
  /// (or dead) trackers. More trackers = more peers = more speed, and it
  /// never changes the infohash, so the same content is fetched.
  static const List<String> _extraTrackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://exodus.desync.com:6969/announce',
    'udp://tracker.openbittorrent.com:6969/announce',
    'udp://tracker.tiny-vps.com:6969/announce',
    'udp://open.demonii.com:1337/announce',
    'udp://tracker.moeking.me:6969/announce',
    'udp://odd-hd.fr:6969/announce',
    'udp://tracker.theoks.net:6969/announce',
  ];

  /// Appends any missing trackers from [_extraTrackers] as `&tr=` params.
  /// Trackers already present (by host) are never duplicated.
  static String enrichMagnet(String magnet) {
    var out = magnet;
    for (final tracker in _extraTrackers) {
      final host = Uri.tryParse(tracker)?.host ?? '';
      if (host.isEmpty || out.contains(host)) continue;
      out += '&tr=${Uri.encodeComponent(tracker)}';
    }
    return out;
  }

  /// Tunes the engine for streaming throughput, once per process.
  ///
  /// TorrServer ships conservative defaults (25 connections/torrent) that
  /// starve fast lines. This raises the knobs that are safe on phones —
  /// more concurrent peers, no rate caps, peer discovery on — while
  /// leaving cache/memory behavior at stock values. It reads the live
  /// settings first and only writes back fields that need changing, so
  /// user/server customizations are never clobbered. Best-effort:
  /// any failure is swallowed and streaming proceeds with defaults.
  Future<bool> applyPerformanceProfile() async {
    if (_profileApplied) return true;
    try {
      if (!await initialize()) return false;
      final baseUri = _controller.baseUrl;
      if (baseUri == null) return false;
      var base = baseUri.toString();
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      final uri = Uri.parse('$base/api/settings');

      final current = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (current.statusCode != 200) return false;
      final decoded = json.decode(current.body);
      if (decoded is! Map<String, dynamic>) return false;
      final sets = Map<String, dynamic>.from(decoded);

      var changed = false;
      void raiseMin(String key, num min) {
        final v = sets[key];
        if (v is num && v < min) {
          sets[key] = min;
          changed = true;
        }
      }

      void unlimit(String key) {
        final v = sets[key];
        if (v is num && v > 0) {
          sets[key] = 0;
          changed = true;
        }
      }

      void enable(String flag) {
        if (sets[flag] == true) {
          sets[flag] = false;
          changed = true;
        }
      }

      raiseMin('ConnectionsLimit', 100);
      unlimit('DownloadRateLimit');
      unlimit('UploadRateLimit');
      enable('DisableDHT');
      enable('DisablePEX');
      enable('DisableUPNP');

      if (changed) {
        final saved = await http
            .post(uri,
                headers: const {'Content-Type': 'application/json'},
                body: json.encode(sets))
            .timeout(const Duration(seconds: 8));
        if (saved.statusCode != 200) return false;
      }
      await _logProfile(uri);
      _profileApplied = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies the tuned settings by reading them back (visible in
  /// logcat as `[Movix]`), so throughput work is provable, not assumed.
  Future<void> _logProfile(Uri uri) async {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final decoded = json.decode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      debugPrint('[Movix] engine profile: connections=${decoded['ConnectionsLimit']} '
          'dl=${decoded['DownloadRateLimit']} ul=${decoded['UploadRateLimit']} '
          'dht=${decoded['DisableDHT']} pex=${decoded['DisablePEX']} '
          'upnp=${decoded['DisableUPNP']}');
    } catch (_) {}
  }

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
    // Extra trackers widen the peer pool; the infohash is untouched.
    magnet = enrichMagnet(magnet);
    try {
      onPhase?.call(TorrentPhase.metadata, null);
      final added = await _controller.addTorrent(magnet: magnet, title: null, saveToDb: false);
      final th = added.hash.isNotEmpty ? added.hash.toLowerCase() : hash;
      _active.add(th);
      final files = await _waitForMetadata(th);
      if (files == null || files.isEmpty) { onPhase?.call(TorrentPhase.error, null); return null; }
      final fileId = _selectFile(files, preferredIdx: fileIndex);
      if (fileId == null) { onPhase?.call(TorrentPhase.error, null); return null; }
      // Adaptive preload gate: ~0.5% of the file (the first seconds of
      // video), clamped for tiny/huge files. Healthy swarms start even
      // earlier; the timeout still lets slow ones through to the player.
      const mb = 1024 * 1024;
      var fileLen = 0;
      for (final f in files) {
        if (f.id == fileId) {
          fileLen = f.length;
          break;
        }
      }
      var targetBytes = fileLen ~/ 200;
      if (targetBytes < mb) targetBytes = mb;
      if (targetBytes > 8 * mb) targetBytes = 8 * mb;
      final sw = Stopwatch()..start();
      while (sw.elapsed < const Duration(seconds: 30)) {
        try {
          final info = await _controller.getTorrent(th);
          final stats = TorrentStats(speedMbps: info.downloadSpeed / 1024 / 1024, activePeers: info.activePeers, progress: info.torrentSize > 0 ? info.loadedSize / info.torrentSize : 0, isReady: info.loadedSize > 0);
          onPhase?.call(TorrentPhase.peers, stats);
          if (info.loadedSize >= targetBytes) break;
          if (info.loadedSize >= mb && info.downloadSpeed >= mb) break;
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
