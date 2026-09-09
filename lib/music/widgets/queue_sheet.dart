import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';

/// Queue bottom sheet: tap to jump, drag to reorder, swipe-free
/// delete buttons, shuffle + clear actions.
Future<void> showQueueSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _QueueSheetBody(),
  );
}

class _QueueSheetBody extends StatefulWidget {
  const _QueueSheetBody();

  @override
  State<_QueueSheetBody> createState() => _QueueSheetBodyState();
}

class _QueueSheetBodyState extends State<_QueueSheetBody> {
  final _controller = MusicPlayerController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ValueListenableBuilder<MusicPlayerState>(
            valueListenable: _controller.state,
            builder: (context, s, _) {
              final items = _controller.queue.items;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Queue',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.text)),
                            Text('${items.length} tracks',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textDim)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _controller.toggleShuffle();
                          setState(() {});
                        },
                        icon: Icon(Icons.shuffle_rounded,
                            color: s.shuffle
                                ? AppTheme.accent
                                : AppTheme.textDim),
                        tooltip: 'Shuffle',
                      ),
                      IconButton(
                        onPressed: () {
                          _controller.clearQueue();
                          setState(() {});
                        },
                        icon: const Icon(
                            Icons.delete_sweep_outlined,
                            color: AppTheme.textDim),
                        tooltip: 'Clear queue',
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: AppTheme.textDim, size: 20),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Queue is empty.',
                            style: TextStyle(
                                color: AppTheme.textDim)),
                      ),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        onReorder: (oldI, newI) {
                          setState(() {
                            _controller.move(
                                oldI, newI > oldI ? newI - 1 : newI);
                          });
                        },
                        itemBuilder: (c, i) {
                          final item = items[i];
                          final t = item.track;
                          final isCurrent =
                              s.current?.queueId == item.queueId;
                          return Container(
                            key: ValueKey(item.queueId),
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppTheme.accent.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.045),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                  color: isCurrent
                                      ? AppTheme.accent
                                          .withOpacity(0.4)
                                      : AppTheme.stroke),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: AppTheme.textFaint,
                                        size: 20),
                                  ),
                                ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    color: AppTheme.surface,
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: t.artworkSmall.isEmpty
                                        ? const Center(
                                            child: Icon(
                                                Icons.music_note_rounded,
                                                color:
                                                    AppTheme.textDim,
                                                size: 20),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl:
                                                t.artworkSmall,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 120,
                                            fadeInDuration:
                                                AppTheme.fast,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _controller.playAt(i),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(t.title,
                                            maxLines: 1,
                                            overflow: TextOverflow
                                                .ellipsis,
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: isCurrent
                                                    ? AppTheme.accent
                                                    : AppTheme.text)),
                                        Text(t.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow
                                                .ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme
                                                    .textDim)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isCurrent &&
                                    (s.status ==
                                            MusicStatus.playing ||
                                        s.status ==
                                            MusicStatus.buffering))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                        Icons
                                            .graphic_eq_rounded,
                                        color: AppTheme.accent,
                                        size: 20),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    _controller.removeAt(i);
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.textFaint,
                                      size: 18),
                                  tooltip: 'Remove',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
