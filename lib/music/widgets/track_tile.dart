import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../models/music_models.dart';
import '../player/music_player_controller.dart';

String formatTrackDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Standard track row: artwork, title/artist, duration, like + options.
/// [queueForTap] is the list [onTap] indexes into (usually the row's
/// whole result list); pass an explicit index-aware callback instead
/// when the row order differs.
class TrackTile extends StatefulWidget {
  final Track track;
  final VoidCallback onTap;
  final bool showLike;

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.showLike = true,
  });

  @override
  State<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile> {
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    MusicPlayerController().isLiked(widget.track.id).then((v) {
      if (mounted) setState(() => _liked = v);
    });
  }

  Future<void> _toggleLike() async {
    final v =
        await MusicPlayerController().toggleLike(widget.track);
    if (mounted) setState(() => _liked = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Pressable(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppTheme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: t.artworkSmall.isEmpty
                    ? const Center(
                        child: Icon(Icons.music_note_rounded,
                            color: AppTheme.textDim, size: 24),
                      )
                    : CachedNetworkImage(
                        imageUrl: t.artworkSmall,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        fadeInDuration: AppTheme.fast,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (t.explicit) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.textFaint),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('E',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textFaint)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textDim)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (t.durationMs > 0)
              Text(formatTrackDuration(t.durationMs),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textDim)),
            if (widget.showLike)
              IconButton(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color:
                      _liked ? AppTheme.accent : AppTheme.textDim,
                  size: 20,
                ),
                tooltip: _liked ? 'Unlike' : 'Like',
              ),
            IconButton(
              onPressed: () => showTrackOptions(context, t),
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textDim, size: 20),
              tooltip: 'Options',
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: play next / queue / playlist actions for a track.
Future<void> showTrackOptions(BuildContext context, Track track) async {
  final controller = MusicPlayerController();
  await showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(c).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Play next'),
              onTap: () {
                controller.insertNext(track);
                Navigator.pop(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                controller.addToQueue(track);
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to queue')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist…'),
              onTap: () {
                Navigator.pop(c);
                showPlaylistPicker(context, track);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet listing local playlists to add [track] to (plus create).
Future<void> showPlaylistPicker(BuildContext context, Track track) async {
  final controller = MusicPlayerController();
  final playlists = await controller.playlists();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(c).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: () async {
                Navigator.pop(c);
                final name = await _askPlaylistName(context);
                if (name == null || !context.mounted) return;
                final pl = await controller.createPlaylist(name);
                await controller.addToPlaylist(pl.id, track);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to ${pl.name}')),
                );
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final pl in playlists)
                    ListTile(
                      leading: const Icon(
                          Icons.queue_music_outlined),
                      title: Text(pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text('${pl.tracks.length} tracks',
                          style: const TextStyle(fontSize: 12)),
                      onTap: () async {
                        await controller.addToPlaylist(pl.id, track);
                        if (!c.mounted) return;
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Added to ${pl.name}')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askPlaylistName(BuildContext context) async {
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
        onSubmitted: (_) =>
            Navigator.pop(c, ctrl.text.trim()),
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
