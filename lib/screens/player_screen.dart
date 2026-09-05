import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/stream_result.dart';
import '../models/media_item.dart';
import '../services/torrent/torrent_service.dart';
import '../services/watch_progress_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final StreamResult result;
  final String title;
  final MediaItem item;
  final int? season;
  final int? episode;
  const PlayerScreen({super.key, required this.result, required this.title, required this.item, this.season, this.episode});
  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  final TorrentService _torrent = TorrentService();
  final WatchProgressService _wp = WatchProgressService();
  final ValueNotifier<TorrentStats?> _stats = ValueNotifier(null);
  StreamSubscription<TorrentStats>? _statsSub;
  bool _playing = false, _buffering = true, _opened = false, _failed = false, _controlsVisible = true, _isTorrent = false;
  TorrentPhase _phase = TorrentPhase.metadata;
  Duration _position = Duration.zero, _duration = Duration.zero;
  double _rate = 1.0, _volume = 100;
  int _openedAt = 0;
  Timer? _hideTimer, _saveTimer, _watchdog;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _player = Player(configuration: PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
    _videoController = VideoController(_player);
    _subs.add(_player.streams.playing.listen((v) { if (mounted) setState(() => _playing = v); }));
    _subs.add(_player.streams.buffering.listen((v) { if (mounted) setState(() => _buffering = v); }));
    _subs.add(_player.streams.position.listen((v) { if (mounted) setState(() => _position = v); }));
    _subs.add(_player.streams.duration.listen((v) { if (mounted) setState(() => _duration = v ?? Duration.zero); }));
    _subs.add(_player.streams.volume.listen((v) { if (mounted) setState(() => _volume = v); }));
    _subs.add(_player.streams.rate.listen((v) { if (mounted) setState(() => _rate = v); }));
    _isTorrent = widget.result.isTorrent;
    _open();
    _scheduleHide();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!_opened && now - _openedAt > (_isTorrent ? 90000 : 60000)) setState(() => _failed = true);
      else if (_opened && !_playing && _duration == Duration.zero && now - _openedAt > 45000) setState(() => _failed = true);
    });
  }

  Future<void> _open() async {
    setState(() { _failed = false; _buffering = true; _openedAt = DateTime.now().millisecondsSinceEpoch; });
    try {
      String? url = widget.result.url;
      if (_isTorrent && widget.result.magnet != null) {
        url = await _torrent.startStream(magnet: widget.result.magnet!, fileIndex: widget.result.fileIndex, onPhase: (p, s) { if (s != null) _stats.value = s; if (mounted && !_opened) setState(() => _phase = p); });
        if (url == null) { if (mounted) setState(() => _failed = true); return; }
        _statsSub?.cancel();
        _statsSub = _torrent.statsStream(widget.result.magnet!).listen((s) => _stats.value = s);
      }
      await _player.open(Media(url!));
      if (mounted) setState(() => _opened = true);
      await _tryResume();
    } catch (e) { if (mounted) setState(() => _failed = true); }
  }

  String _phaseText() => switch (_phase) { TorrentPhase.engine => 'Starting engine…', TorrentPhase.metadata => _isTorrent ? 'Fetching torrent info…' : 'Loading…', TorrentPhase.peers => 'Connecting to peers…', TorrentPhase.ready => 'Starting playback…', TorrentPhase.error => 'Engine could not start' };

  Future<void> _tryResume() async {
    final progress = widget.item.mediaType == 'tv' ? await _wp.loadEpisode(widget.item.id, widget.season ?? 1, widget.episode ?? 1) : await _wp.loadMovie(widget.item.id);
    if (progress != null && progress.isResumable && mounted) {
      final r = Duration(milliseconds: progress.positionMs);
      if (_duration.inMilliseconds > 0) {
        _player.seek(r);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && _duration.inMilliseconds > 0) _player.seek(r);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resumed from ${progress.positionLabel}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0 || _position.inMilliseconds < 0) return;
    if (widget.item.mediaType == 'tv') await _wp.saveEpisode(id: widget.item.id, season: widget.season ?? 1, episode: widget.episode ?? 1, positionMs: _position.inMilliseconds, durationMs: _duration.inMilliseconds, title: widget.title);
    else await _wp.saveMovie(id: widget.item.id, positionMs: _position.inMilliseconds, durationMs: _duration.inMilliseconds, title: widget.title);
  }

  void _scheduleHide() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _controlsVisible = false); }); }
  void _toggleControls() { setState(() => _controlsVisible = !_controlsVisible); if (_controlsVisible) _scheduleHide(); }
  void _tapSeek(bool forward) {
    _seekBy(forward ? 10 : -10);
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }
  String _fmt(Duration d) { final h = d.inHours, m = d.inMinutes.remainder(60).toString().padLeft(2, '0'), s = d.inSeconds.remainder(60).toString().padLeft(2, '0'); return h > 0 ? '$h:$m:$s' : '$m:$s'; }
  void _seekBy(int seconds) { final t = _position + Duration(seconds: seconds); _player.seek(t < Duration.zero ? Duration.zero : (_duration > Duration.zero && t > _duration ? _duration : t)); }

  @override
  void dispose() {
    _saveProgress(); _saveTimer?.cancel(); _hideTimer?.cancel(); _watchdog?.cancel();
    for (final s in _subs) s.cancel();
    _statsSub?.cancel(); if (_isTorrent) _torrent.cleanup();
    _player.dispose(); _stats.dispose(); WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds.clamp(0, _duration.inMilliseconds) / _duration.inMilliseconds)
        : 0.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: (d) {
            final w = MediaQuery.of(context).size.width;
            if (d.globalPosition.dx < w * 0.4) _tapSeek(false);
            if (d.globalPosition.dx > w * 0.6) _tapSeek(true);
          },
          child: Center(
              child: Video(
                  controller: _videoController,
                  controls: (state) => const SizedBox.shrink())),
        ),
        // Cinematic vignette for controls readability
        AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: AppTheme.med,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, size: 20),
                              onPressed: () => Navigator.pop(context)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            if (_isTorrent)
                              ValueListenableBuilder<TorrentStats?>(
                                valueListenable: _stats,
                                builder: (c, s, _) => Text(
                                    s == null
                                        ? _phaseText()
                                        : '${s.speedLabel} • ${s.activePeers} peers',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 11.5)),
                              ),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Text(_fmt(_position),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.accent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: AppTheme.accent.withOpacity(0.2),
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              ),
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
                                      ? (v) => _player
                                          .seek(Duration(milliseconds: v.toInt()))
                                      : null),
                            ),
                          ),
                          Text(_fmt(_duration),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                        ]),
                        Row(children: [
                          _roundBtn(Icons.replay_10_rounded, () => _seekBy(-10)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _player.playOrPause(),
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.glowShadow,
                              ),
                              child: Icon(
                                  _playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 30,
                                  color: AppTheme.onAccent),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _roundBtn(Icons.forward_10_rounded, () => _seekBy(10)),
                          const Spacer(),
                          if (_isTorrent)
                            ValueListenableBuilder<TorrentStats?>(
                                valueListenable: _stats,
                                builder: (c, s, _) => s == null
                                    ? const SizedBox.shrink()
                                    : Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(s.speedLabel,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w700)),
                                      )),
                          PopupMenuButton<double>(
                            onSelected: (v) => _player.setRate(v),
                            color: AppTheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                .map((v) => PopupMenuItem(
                                    value: v, child: Text('${v}x')))
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${_rate}x',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_opened && !_failed)
          Center(
              child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: AppTheme.accent)),
                  const SizedBox(height: 14),
                  Text(_phaseText(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  if (_isTorrent)
                    ValueListenableBuilder<TorrentStats?>(
                        valueListenable: _stats,
                        builder: (c, s, _) => s == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    '${s.speedLabel} • ${s.activePeers} peers • ${(s.progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)))),
                ]),
              ),
            ),
          )),
        if (_opened && _buffering && !_failed && !_controlsVisible)
          const Center(
              child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70))),
        if (_failed)
          Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.danger.withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppTheme.danger),
                    ),
                    const SizedBox(height: 14),
                    const Text('Stream failed to load',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    if (_isTorrent) ...[
                      const SizedBox(height: 6),
                      Text(
                          'Last stage: ${_phaseText()}\nTip: pick a source with more peers.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12.5, height: 1.5))
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                            onPressed: _open,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry')),
                        const SizedBox(width: 10),
                        OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white24)),
                            child: const Text('Back')),
                      ],
                    )
                  ]))),
      ]),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: IconButton(
          icon: Icon(icon, size: 22), onPressed: () { onTap(); _scheduleHide(); }),
    );
  }
}
