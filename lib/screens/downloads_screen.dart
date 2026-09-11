import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../music/models/music_models.dart';
import '../music/player/music_player_controller.dart';
import '../music/screens/music_player_screen.dart';
import '../music/services/music_download_service.dart';
import '../services/downloads/video_download_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';

/// Downloads tab (replaces Library in the bottom nav): offline videos
/// and music in one place, each with live progress, details and
/// play/delete actions.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with AutomaticKeepAliveClientMixin {
  final _videos = VideoDownloadService.instance;
  final _music = MusicDownloadService.instance;
  int _tab = 0; // 0 = videos, 1 = music

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _videos.init();
    _music.init();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text('Downloads',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () {
              _videos.clearFinished();
              _music.clearCompletedTasks();
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Clear finished',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation:
            Listenable.merge([_videos, _music]),
        builder: (context, _) {
          return ListView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 110 + MediaQuery.of(context).padding.bottom),
            children: [
              _storageCard(),
              const SizedBox(height: 14),
              _categorySwitch(),
              const SizedBox(height: 14),
              if (_tab == 0) ..._videoBodies() else ..._musicBodies(),
            ],
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _storageCard() {
    final total = _videos.totalSizeBytes + _music.totalDownloadedSizeBytes;
    final activeCount =
        _videos.active.length + _music.queue.where((t) => _isMusicActive(t)).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.glowShadow,
            ),
            child: const Icon(Icons.offline_pin_rounded,
                color: AppTheme.onAccent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_videos.downloaded.length} videos • ${_music.downloadedTracks.length} tracks',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.text),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatBytes(total)} on this device'
                  '${activeCount > 0 ? ' • $activeCount active' : ''}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySwitch() {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        side: const BorderSide(color: AppTheme.stroke),
        selectedForegroundColor: AppTheme.onAccent,
        selectedBackgroundColor: AppTheme.accent,
      ),
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.movie_outlined, size: 18),
          label: Text('Videos'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.music_note_outlined, size: 18),
          label: Text('Music'),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
  }

  // ── Videos ─────────────────────────────────────────────

  List<Widget> _videoBodies() {
    final active = _videos.active;
    final done = _videos.downloaded;
    if (active.isEmpty && done.isEmpty) {
      return [
        _empty(
          icon: Icons.download_outlined,
          title: 'No video downloads yet',
          hint:
              'Tap the download button in the player to watch movies offline.',
        )
      ];
    }
    return [
      if (active.isNotEmpty) ...[
        _sectionLabel('Downloading • ${active.length}'),
        for (final t in active) _videoTaskTile(t),
        const SizedBox(height: 8),
      ],
      if (done.isNotEmpty) ...[
        _sectionLabel('Downloaded • ${done.length}'),
        for (final v in done) _videoTile(v),
      ],
    ];
  }

  Widget _videoTaskTile(VideoDownloadTask t) {
    final failed = t.status == VideoDownloadStatus.failed;
    final pct = t.progress < 0
        ? null
        : t.progress.clamp(0.0, 1.0);
    return _row(
      art: t.posterUrl,
      title: t.title,
      subtitle: failed
          ? (t.errorMessage ?? 'Download failed')
          : '${t.detail}\n${_formatBytes(t.bytesDownloaded)}'
              '${t.totalBytes > 0 ? ' of ${_formatBytes(t.totalBytes)}' : ''}',
      trailing: failed
          ? IconButton(
              onPressed: () => _videos.cancelTask(t.id),
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textDim),
              tooltip: 'Dismiss',
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pct != null)
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppTheme.accent)),
                IconButton(
                  onPressed: () => _videos.cancelTask(t.id),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textDim),
                  tooltip: 'Cancel',
                ),
              ],
            ),
      progress: pct,
    );
  }

  Widget _videoTile(DownloadedVideo v) {
    return _row(
      art: v.posterUrl,
      title: v.title,
      subtitle:
          '${v.detail}\n${_formatBytes(v.sizeBytes)} • ${_formatDate(v.downloadedAt)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _playDownloadedVideo(v),
            icon: const Icon(Icons.play_arrow_rounded,
                color: AppTheme.accent, size: 28),
            tooltip: 'Play offline',
          ),
          IconButton(
            onPressed: () => _videos.deleteDownload(v.videoId),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.textDim),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  void _playDownloadedVideo(DownloadedVideo v) {
    final tv = v.mediaType == 'tv';
    final item = MediaItem(
      id: v.itemId,
      title: v.title,
      overview: '',
      posterPath: v.posterUrl,
      mediaType: v.mediaType,
      releaseYear: '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          result: StreamResult(
            sourceName: v.sourceName,
            label: '${v.title} (Offline)',
            url: File(v.localPath).uri.toString(),
            kind: StreamKind.http,
          ),
          title: tv ? '${v.title} • S${v.season} E${v.episode}' : v.title,
          item: item,
          season: tv ? v.season : null,
          episode: tv ? v.episode : null,
        ),
      ),
    );
  }

  // ── Music ──────────────────────────────────────────────

  bool _isMusicActive(MusicDownloadTask t) =>
      t.status == MusicDownloadStatus.queued ||
      t.status == MusicDownloadStatus.extracting ||
      t.status == MusicDownloadStatus.downloading;

  List<Widget> _musicBodies() {
    final active =
        _music.queue.where(_isMusicActive).toList();
    final failed = _music.queue
        .where((t) => t.status == MusicDownloadStatus.failed)
        .toList();
    final done = _music.downloadedTracks;
    if (active.isEmpty && failed.isEmpty && done.isEmpty) {
      return [
        _empty(
          icon: Icons.music_note_outlined,
          title: 'No music downloads yet',
          hint:
              'Tap the download button in the music player to listen offline.',
        )
      ];
    }
    return [
      if (active.isNotEmpty) ...[
        _sectionLabel('Downloading • ${active.length}'),
        for (final t in active) _musicTaskTile(t),
        const SizedBox(height: 8),
      ],
      if (failed.isNotEmpty) ...[
        _sectionLabel('Failed • ${failed.length}'),
        for (final t in failed)
          _row(
            art: _musicArt(t.track),
            title: t.track.title,
            subtitle: t.errorMessage ?? 'Download failed',
            trailing: IconButton(
              onPressed: () => _music.cancelTask(t.track.id),
              icon: const Icon(Icons.close_rounded,
                  color: AppTheme.textDim),
              tooltip: 'Dismiss',
            ),
          ),
        const SizedBox(height: 8),
      ],
      if (done.isNotEmpty) ...[
        _sectionLabel('Downloaded • ${done.length}'),
        for (final d in done) _musicTile(d),
      ],
    ];
  }

  Widget _musicTaskTile(MusicDownloadTask t) {
    final pct = t.totalBytes > 0
        ? (t.bytesDownloaded / t.totalBytes).clamp(0.0, 1.0)
        : null;
    final phase = switch (t.status) {
      MusicDownloadStatus.extracting => 'Finding audio…',
      _ => 'Downloading…',
    };
    return _row(
      art: _musicArt(t.track),
      title: t.track.title,
      subtitle:
          '${t.track.artist}\n$phase ${_formatBytes(t.bytesDownloaded)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pct != null)
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppTheme.accent)),
          IconButton(
            onPressed: () => _music.cancelTask(t.track.id),
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.textDim),
            tooltip: 'Cancel',
          ),
        ],
      ),
      progress: pct,
    );
  }

  Widget _musicTile(DownloadedTrack d) {
    return _row(
      art: _musicArt(d.track),
      title: d.track.title,
      subtitle:
          '${d.track.artist}\n${d.quality} • ${_formatBytes(d.fileSizeBytes)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              MusicPlayerController().playTracks([d.track]);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MusicPlayerScreen()),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded,
                color: AppTheme.accent, size: 28),
            tooltip: 'Play offline',
          ),
          IconButton(
            onPressed: () =>
                _music.deleteDownloadedTrack(d.track.id),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.textDim),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  String _musicArt(Track t) =>
      t.artworkSmall.isNotEmpty ? t.artworkSmall : t.artworkLarge;

  // ── Shared rows ────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppTheme.textDim)),
    );
  }

  Widget _row({
    required String? art,
    required String title,
    required String subtitle,
    required Widget trailing,
    double? progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: (art != null && art.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: art,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          fadeInDuration: AppTheme.fast,
                          placeholder: (c, u) => Container(
                              color: AppTheme.bgHi),
                          errorWidget: (c, u, e) => Container(
                            color: AppTheme.bgHi,
                            child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.textFaint,
                                size: 22),
                          ),
                        )
                      : Container(
                          color: AppTheme.bgHi,
                          child: const Icon(
                              Icons.movie_outlined,
                              color: AppTheme.textFaint,
                              size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accent),
              ),
            ),
          ] else if (progress == null &&
              trailing is! IconButton) ...[
            // Unknown-size downloads still show motion.
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty(
      {required IconData icon,
      required String title,
      required String hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Icon(icon, size: 40, color: AppTheme.textDim),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.text)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textDim, fontSize: 13.5)),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
