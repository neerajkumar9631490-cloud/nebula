import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stream_result.dart';
import '../models/media_item.dart';
import '../services/torrent/torrent_service.dart';
import '../services/watch_progress_service.dart';

class PlayerScreen extends StatefulWidget {
  final StreamResult result;
  final String title;
  final MediaItem item;
  final int? season;
  final int? episode;

  const PlayerScreen({
    super.key,
    required this.result,
    required this.title,
    required this.item,
    this.season,
    this.episode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  final TorrentService _torrent = TorrentService();
  final WatchProgressService _wp = WatchProgressService();

  final ValueNotifier<TorrentStats?> _stats = ValueNotifier(null);
  StreamSubscription<TorrentStats>? _statsSub;

  bool _playing = false;
  bool _buffering = true;
  bool _opened = false;
  bool _failed = false;
  bool _controlsVisible = true;
  bool _orientationLocked = false;
  bool _isTorrent = false;
  TorrentPhase _phase = TorrentPhase.metadata;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _rate = 1.0;
  double _volume = 100;
  int _openedAt = 0;

  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _watchdog;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player(
      configuration: PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    _videoController = VideoController(_player);

    _subs.add(_player.streams.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));
    _subs.add(_player.streams.buffering.listen((v) {
      if (mounted) setState(() => _buffering = v);
    }));
    _subs.add(_player.streams.position.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subs.add(_player.streams.duration.listen((v) {
      if (mounted) setState(() => _duration = v ?? Duration.zero);
    }));
    _subs.add(_player.streams.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    }));
    _subs.add(_player.streams.rate.listen((v) {
      if (mounted) setState(() => _rate = v);
    }));

    _isTorrent = widget.result.isTorrent;
    _open();
    _scheduleHide();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());

    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!_opened && now - _openedAt > 120000) {
        setState(() => _failed = true);
      } else if (_opened && !_playing && _duration == Duration.zero && now - _openedAt > 45000) {
        setState(() => _failed = true);
      }
    });
  }

  Future<void> _open() async {
    setState(() {
      _failed = false;
      _buffering = true;
      _openedAt = DateTime.now().millisecondsSinceEpoch;
    });

    try {
      String? url = widget.result.url;

      if (_isTorrent && widget.result.magnet != null) {
        url = await _torrent.startStream(
          magnet: widget.result.magnet!,
          fileIndex: widget.result.fileIndex,
          onPhase: (p, s) {
            if (s != null) _stats.value = s;
            if (mounted && !_opened) setState(() => _phase = p);
          },
        );
        if (url == null) {
          if (mounted) setState(() { _failed = true; });
          return;
        }
        _statsSub = _torrent.statsStream(widget.result.magnet!).listen((s) {
          _stats.value = s;
        });
      }

      await _player.open(Media(url!));
      if (mounted) setState(() => _opened = true);
      await _tryResume();
    } catch (e) {
      debugPrint('Player error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  String _phaseText() => switch (_phase) {
        TorrentPhase.engine => 'Starting engine…',
        TorrentPhase.metadata => _isTorrent ? 'Fetching torrent info…' : 'Loading…',
        TorrentPhase.peers => 'Connecting to peers…',
        TorrentPhase.ready => 'Starting…',
        TorrentPhase.error => 'Engine could not start',
      };

  Future<void> _tryResume() async {
    final progress = widget.item.mediaType == 'tv'
        ? await _wp.loadEpisode(widget.item.id, widget.season ?? 1, widget.episode ?? 1)
        : await _wp.loadMovie(widget.item.id);
    if (progress != null && progress.isResumable && mounted) {
      final r = Duration(milliseconds: progress.positionMs);
      if (_duration.inMilliseconds > 0) {
        _player.seek(r);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && _duration.inMilliseconds > 0) _player.seek(r);
      }
    }
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0 || _position.inMilliseconds < 0) return;
    if (widget.item.mediaType == 'tv') {
      await _wp.saveEpisode(
        id: widget.item.id,
        season: widget.season ?? 1,
        episode: widget.episode ?? 1,
        positionMs: _position.inMilliseconds,
        durationMs: _duration.inMilliseconds,
        title: widget.title,
      );
    } else {
      await _wp.saveMovie(
        id: widget.item.id,
        positionMs: _position.inMilliseconds,
        durationMs: _duration.inMilliseconds,
        title: widget.title,
      );
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _seekBy(int seconds) {
    final t = _position + Duration(seconds: seconds);
    final c = t < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && t > _duration ? _duration : t);
    _player.seek(c);
  }

  void _toggleOrientationLock() async {
    final locked = !_orientationLocked;
    setState(() => _orientationLocked = locked);
    if (locked) {
      final o = MediaQuery.of(context).orientation;
      await SystemChrome.setPreferredOrientations(o == Orientation.landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp]);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  void _openExternal() async {
    final m = widget.result.magnet;
    if (m == null) return;
    final uri = Uri.parse(m);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    _watchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _statsSub?.cancel();
    if (_isTorrent) _torrent.cleanup();
    _player.dispose();
    _stats.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleControls,
            child: Center(
              child: Video(
                controller: _videoController,
                controls: (state) => const SizedBox.shrink(),
              ),
            ),
          ),
          if (!_opened && !_failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 14),
                  Text(_phaseText(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (_isTorrent)
                    ValueListenableBuilder<TorrentStats?>(
                      valueListenable: _stats,
                      builder: (c, s, _) => s == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${s.speedLabel} • ${s.activePeers} peers',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          if (_opened && _buffering && !_failed)
            const Center(
              child: Opacity(
                opacity: 0.5,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            ),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orangeAccent),
                    const SizedBox(height: 8),
                    const Text('Stream failed to load', style: TextStyle(color: Colors.white70)),
                    if (_isTorrent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last stage: ${_phaseText()}\nTip: pick a source with more peers (4K/1080p with many seeders).',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: _open,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        if (_isTorrent && widget.result.magnet != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _openExternal,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('External'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_controlsVisible && !_failed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_orientationLocked ? Icons.screen_lock_rotation : Icons.screen_rotation),
                        onPressed: _toggleOrientationLock,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_controlsVisible && !_failed)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.black54,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(_fmt(_position), style: const TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                                  : 0,
                              max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1,
                              onChanged: _duration.inMilliseconds > 0
                                  ? (v) => _player.seek(Duration(milliseconds: v.toInt()))
                                  : null,
                            ),
                          ),
                          Text(_fmt(_duration), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _seekBy(-10)),
                          IconButton(
                            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 36),
                            onPressed: () => _player.playOrPause(),
                          ),
                          IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _seekBy(10)),
                          const Spacer(),
                          if (_isTorrent)
                            ValueListenableBuilder<TorrentStats?>(
                              valueListenable: _stats,
                              builder: (c, s, _) => s == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Text(
                                        '${s.speedLabel} • ${s.activePeers}',
                                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                                      ),
                                    ),
                            ),
                          Icon(_volume == 0 ? Icons.volume_off : Icons.volume_down, size: 18),
                          SizedBox(
                            width: 90,
                            child: Slider(
                              value: _volume.clamp(0, 100),
                              max: 100,
                              onChanged: (v) => _player.setVolume(v),
                            ),
                          ),
                          PopupMenuButton<double>(
                            onSelected: (v) => _player.setRate(v),
                            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                .map((v) => PopupMenuItem(value: v, child: Text('${v}x')))
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('${_rate}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
