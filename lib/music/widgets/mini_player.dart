import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../player/music_player_controller.dart';
import '../screens/music_player_screen.dart';

/// Persistent mini player pinned above the bottom navigation. Visible
/// whenever a track is loaded; survives tab switches because the
/// controller is app-scoped. Tap opens the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerController();
    return ValueListenableBuilder<MusicPlayerState>(
      valueListenable: controller.state,
      builder: (context, s, _) {
        final track = s.current?.track;
        if (track == null || s.status == MusicStatus.idle) {
          return const SizedBox.shrink();
        }
        final playing = s.status == MusicStatus.playing ||
            s.status == MusicStatus.buffering ||
            s.status == MusicStatus.loading;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MusicPlayerScreen()),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xF016161D),
              border: Border(
                  top: BorderSide(color: AppTheme.stroke, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thin live progress edge.
                StreamBuilder<Duration>(
                  stream: controller.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? controller.currentPosition;
                    final total = controller.currentDuration;
                    final v = total.inMilliseconds > 0
                        ? (pos.inMilliseconds /
                                total.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return LinearProgressIndicator(
                      value: v,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              AppTheme.accent),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.surface,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: track.artworkSmall.isEmpty
                              ? const Center(
                                  child: Icon(
                                      Icons.music_note_rounded,
                                      color: AppTheme.textDim,
                                      size: 22),
                                )
                              : CachedNetworkImage(
                                  imageUrl: track.artworkSmall,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  fadeInDuration: AppTheme.fast,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text)),
                            Text(track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      if (s.status == MusicStatus.error)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.error_outline_rounded,
                              color: AppTheme.textDim, size: 20),
                        ),
                      IconButton(
                        onPressed: controller.toggle,
                        icon: s.status == MusicStatus.loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5),
                              )
                            : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: AppTheme.text,
                                size: 28,
                              ),
                      ),
                      IconButton(
                        onPressed: controller.next,
                        icon: const Icon(Icons.skip_next_rounded,
                            color: AppTheme.textDim, size: 24),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
