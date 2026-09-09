import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';
import '../screens/music_player_screen.dart';
import 'track_tile.dart';

/// Bottom sheet showing a playlist's tracks. Tap plays the list from
/// that track; owners can remove tracks or delete the whole playlist.
/// The pseudo playlist `__liked__` is read-only.
Future<void> showPlaylistSheet(
  BuildContext context,
  Playlist playlist, {
  bool readOnly = false,
}) async {
  final controller = MusicPlayerController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _PlaylistSheetBody(
      playlist: playlist,
      readOnly: readOnly,
      controller: controller,
    ),
  );
}

Future<String?> askPlaylistName(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: AppTheme.text),
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (_) => Navigator.pop(c, ctrl.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class _PlaylistSheetBody extends StatefulWidget {
  final Playlist playlist;
  final bool readOnly;
  final MusicPlayerController controller;

  const _PlaylistSheetBody({
    required this.playlist,
    required this.readOnly,
    required this.controller,
  });

  @override
  State<_PlaylistSheetBody> createState() => _PlaylistSheetBodyState();
}

class _PlaylistSheetBodyState extends State<_PlaylistSheetBody> {
  late List<Track> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = List.of(widget.playlist.tracks);
  }

  Future<void> _reload() async {
    if (widget.readOnly) {
      final liked = await widget.controller.likedTracks();
      if (mounted) setState(() => _tracks = liked.values.toList());
      return;
    }
    final all = await widget.controller.playlists();
    final match = all.where((p) => p.id == widget.playlist.id).toList();
    if (mounted && match.isNotEmpty) {
      setState(() => _tracks = List.of(match.first.tracks));
    }
  }

  void _playAt(int index) {
    widget.controller.playTracks(_tracks, startIndex: index);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.text)),
                        Text('${_tracks.length} tracks',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textDim)),
                      ],
                    ),
                  ),
                  if (!widget.readOnly)
                    IconButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('Delete playlist?'),
                            content: Text(
                                '"${widget.playlist.name}" will be removed. Tracks stay in your library.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(d, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(d, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await widget.controller
                              .deletePlaylist(widget.playlist.id);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.textDim),
                      tooltip: 'Delete playlist',
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
              const SizedBox(height: 12),
              if (_tracks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Nothing here yet — like some tracks first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textDim)),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _tracks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (c, i) {
                      final t = _tracks[i];
                      return Dismissible(
                        key: ValueKey(
                            '${widget.playlist.id}_${t.id}_$i'),
                        direction: widget.readOnly
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(right: 18),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF6B6B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF6B6B)),
                        ),
                        onDismissed: (_) async {
                          await widget.controller.removeFromPlaylist(
                              widget.playlist.id, t.id);
                          _reload();
                        },
                        child: TrackTile(
                          track: t,
                          onTap: () => _playAt(i),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
