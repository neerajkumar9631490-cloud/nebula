import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/stream_result.dart';
import '../services/torrent/torrent_service.dart';

class PlayerScreen extends StatefulWidget {
  final StreamResult result;
  final String title;

  const PlayerScreen({super.key, required this.result, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  final TorrentService _torrentService = TorrentService();

  bool _playing = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _orientationLocked = false;
  bool _failed = false;
  bool _isTorrent = false;
  TorrentStats? _torrentStats;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _rate = 1.0;
  double _volume = 100;

  Timer? _failTimer;
  Timer? _hideTimer;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
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
  }

  Future<void> _open() async {
    setState(() {
      _failed = false;
      _buffering = true;
    });

    try {
      String? url = widget.result.url;

      if (_isTorrent && widget.result.magnet != null) {
        // Start torrent streaming
        url = await _torrentService.startStream(
          magnet: widget.result.magnet!,
          fileIndex: widget.result.fileIndex,
          onStats: (stats) {
            if (mounted) {
              setState(() => _torrentStats = stats);
              // Stop buffering once we have peers
              if (stats.isReady && _buffering) {
                setState(() => _buffering = false);
              }
            }
          },
        );

        if (url == null) {
          setState(() {
            _failed = true;
            _buffering = false;
          });
          return;
        }
      }

      if (url != null) {
        await _player.open(Media(url));
      }
    } catch (e) {
      debugPrint('Player error: $e');
      if (mounted) setState(() => _failed = true);
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
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    _player.seek(clamped);
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

  @override
  void dispose() {
    _failTimer?.cancel();
    _hideTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (_isTorrent) {
      _torrentService.cleanup();
    }
    _player.dispose();
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
          if (_buffering && !_failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_isTorrent && _torrentStats != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Downloading: ${(_torrentStats!.progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Speed: ${_torrentStats!.speedLabel}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      'Peers: ${_torrentStats!.activePeers}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          if (_failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.orangeAccent),
                  const SizedBox(height: 8),
                  Text(_isTorrent ? 'Failed to start torrent stream' : 'Stream failed to load'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _open,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
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
                                  ? _position.inMilliseconds
                                      .clamp(0, _duration.inMilliseconds)
                                      .toDouble()
                                  : 0,
                              max: _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 1,
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
                          IconButton(
                            icon: const Icon(Icons.replay_10),
                            onPressed: () => _seekBy(-10),
                          ),
                          IconButton(
                            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 36),
                            onPressed: () => _player.playOrPause(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10),
                            onPressed: () => _seekBy(10),
                          ),
                          const Spacer(),
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
                                .map((v) => PopupMenuItem(
                                      value: v,
                                      child: Text('${v}x'),
                                    ))
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('${_rate}x',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
