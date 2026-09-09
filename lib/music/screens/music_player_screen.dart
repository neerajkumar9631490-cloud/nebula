import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/track_tile.dart';

/// Full-screen music player: artwork, transport, shuffle/repeat,
/// volume, speed and queue — all driven by [MusicPlayerController].
class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final _controller = MusicPlayerController();
  bool _liked = false;
  String? _likedFor;

  Future<void> _refreshLike(Track? track) async {
    if (track == null) return;
    final v = await _controller.isLiked(track.id);
    if (mounted) {
      setState(() {
        _liked = v;
        _likedFor = track.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        title: const Column(
          children: [
            Text('NOW PLAYING',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.textDim)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => showQueueSheet(context),
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
          ),
        ],
      ),
      body: ValueListenableBuilder<MusicPlayerState>(
        valueListenable: _controller.state,
        builder: (context, s, _) {
          final track = s.current?.track;
          if (track != null && _likedFor != track.id) {
            _refreshLike(track);
          }
          if (track == null) {
            return const Center(
              child: Text('Nothing queued yet.',
                  style: TextStyle(color: AppTheme.textDim)),
            );
          }
          final playing = s.status == MusicStatus.playing ||
              s.status == MusicStatus.buffering;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, 32 + MediaQuery.of(context).padding.bottom),
            children: [
              const SizedBox(height: 8),
              _artwork(track),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.text)),
                        const SizedBox(height: 4),
                        Text(track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textDim)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final v =
                          await _controller.toggleLike(track);
                      if (mounted) setState(() => _liked = v);
                    },
                    icon: Icon(
                      _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _liked
                          ? AppTheme.accent
                          : AppTheme.textDim,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _slider(),
              if (s.status == MusicStatus.error &&
                  s.error != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _controller.toggle,
                  child: Text('${s.error}  •  Tap to retry',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFFFF8A8A))),
                ),
              ],
              const SizedBox(height: 10),
              _transport(playing, s),
              const SizedBox(height: 18),
              _bottomRow(s),
            ],
          );
        },
      ),
    );
  }

  Widget _artwork(Track track) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: track.artworkLarge.isEmpty
              ? Container(
                  color: AppTheme.surface,
                  child: const Center(
                    child: Icon(Icons.music_note_rounded,
                        color: AppTheme.textDim, size: 90),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: track.artworkLarge,
                  fit: BoxFit.cover,
                  memCacheWidth: 640,
                  fadeInDuration: AppTheme.med,
                  placeholder: (c, u) =>
                      Container(color: AppTheme.surface),
                  errorWidget: (c, u, e) => Container(
                    color: AppTheme.surface,
                    child: const Center(
                      child: Icon(Icons.music_note_rounded,
                          color: AppTheme.textDim, size: 90),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _slider() {
    return StreamBuilder<Duration>(
      stream: _controller.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? _controller.currentPosition;
        final total = _controller.currentDuration;
        final totalMs = total.inMilliseconds;
        final posMs =
            pos.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 1);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: Colors.white.withOpacity(0.14),
                thumbColor: Colors.white,
                overlayColor: AppTheme.accent.withOpacity(0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7),
              ),
              child: Slider(
                value: totalMs > 0 ? posMs.toDouble() : 0,
                max: totalMs > 0 ? totalMs.toDouble() : 1,
                onChanged: totalMs > 0
                    ? (v) => _controller
                        .seek(Duration(milliseconds: v.toInt()))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTrackDuration(posMs),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textDim)),
                  Text(
                      totalMs > 0
                          ? '-${formatTrackDuration(totalMs - posMs)}'
                          : '--:--',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textDim)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _transport(bool playing, MusicPlayerState s) {
    final busy = s.status == MusicStatus.loading;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: _controller.toggleShuffle,
          icon: Icon(Icons.shuffle_rounded,
              color: s.shuffle ? AppTheme.accent : AppTheme.textDim,
              size: 24),
          tooltip: s.shuffle ? 'Shuffle on' : 'Shuffle off',
        ),
        IconButton(
          onPressed: _controller.previous,
          icon: const Icon(Icons.skip_previous_rounded,
              color: AppTheme.text, size: 38),
        ),
        GestureDetector(
          onTap: _controller.toggle,
          child: AnimatedContainer(
            duration: AppTheme.fast,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.glowShadow,
            ),
            child: busy
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.onAccent),
                  )
                : Icon(
                    playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppTheme.onAccent,
                    size: 34),
          ),
        ),
        IconButton(
          onPressed: _controller.next,
          icon: const Icon(Icons.skip_next_rounded,
              color: AppTheme.text, size: 38),
        ),
        _repeatButton(s),
      ],
    );
  }

  Widget _repeatButton(MusicPlayerState s) {
    IconData icon;
    Color color = AppTheme.textDim;
    String badge = '';
    switch (s.repeat) {
      case MusicRepeatMode.off:
        icon = Icons.repeat_rounded;
        break;
      case MusicRepeatMode.all:
        icon = Icons.repeat_rounded;
        color = AppTheme.accent;
        break;
      case MusicRepeatMode.one:
        icon = Icons.repeat_one_rounded;
        color = AppTheme.accent;
        badge = '1';
        break;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _controller.cycleRepeat,
          icon: Icon(icon, color: color, size: 24),
          tooltip: 'Repeat: ${s.repeat.name}',
        ),
        if (badge.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppTheme.accent, shape: BoxShape.circle),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onAccent)),
            ),
          ),
      ],
    );
  }

  Widget _bottomRow(MusicPlayerState s) {
    return Row(
      children: [
        const Icon(Icons.volume_down_rounded,
            color: AppTheme.textDim, size: 20),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.textDim,
              inactiveTrackColor:
                  Colors.white.withOpacity(0.14),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6),
            ),
            child: Slider(
              value: s.volume,
              max: 100,
              onChanged: (v) => _controller.setVolume(v),
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _controller.cycleRate,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Text('${s.rate}x',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppTheme.text)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showQueueSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.queue_music_rounded,
                    size: 17, color: AppTheme.text),
                const SizedBox(width: 6),
                Text('${s.queueLength}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppTheme.text)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
