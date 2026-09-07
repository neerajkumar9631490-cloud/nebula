import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/watch_progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'sources_screen.dart';

/// Library tab: everything you started watching, newest first,
/// with one-tap resume straight into sources.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final WatchProgressService _wp = WatchProgressService();
  late Future<List<ContinueEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _wp.listAll();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _wp.listAll());
  }

  Future<void> _resume(ContinueEntry e) async {
    final item = MediaItem(
      id: e.id,
      title: e.title,
      overview: '',
      mediaType: e.mediaType,
      releaseYear: '',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourcesScreen(
          item: item,
          season: e.season,
          episode: e.episode,
        ),
      ),
    );
    _reload();
  }

  Future<void> _remove(ContinueEntry e) async {
    await _wp.clearEntry(e);
    _reload();
  }

  Future<void> _clearAll(List<ContinueEntry> entries) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear library?'),
        content: const Text(
            'All watch progress and resume points will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final e in entries) {
      await _wp.clearEntry(e);
    }
    _reload();
  }

  String _ago(int timestampMs) {
    final d = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestampMs));
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${d.inDays ~/ 30}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library'),
            Text('Pick up where you left off',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: FutureBuilder<List<ContinueEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (c, i) => const Row(
                children: [
                  ShimmerBox(width: 56, height: 84, radius: 14),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                            width: double.infinity, height: 14, radius: 6),
                        SizedBox(height: 8),
                        ShimmerBox(width: 150, height: 11, radius: 6),
                        SizedBox(height: 8),
                        ShimmerBox(width: 200, height: 5, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.stroke),
                      ),
                      child: const Icon(Icons.video_library_outlined,
                          size: 40, color: AppTheme.textDim),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nothing here yet',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text)),
                    const SizedBox(height: 6),
                    const Text(
                        'Start watching anything and it will wait\nfor you right here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textDim, fontSize: 13.5)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => _reload(),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(
                  20, 4, 20, 110 + MediaQuery.of(context).padding.bottom),
              itemCount: entries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Text('${entries.length} title${entries.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _clearAll(entries),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textDim,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Clear all',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  );
                }
                final e = entries[i - 1];
                final pct = e.progress.durationMs > 0
                    ? (e.progress.positionMs / e.progress.durationMs)
                        .clamp(0.0, 1.0)
                    : 0.0;
                final sub = e.isTv
                    ? 'S${e.season} E${e.episode} • ${(pct * 100).toStringAsFixed(0)}% • ${_ago(e.progress.timestampMs)}'
                    : '${(pct * 100).toStringAsFixed(0)}% watched • ${_ago(e.progress.timestampMs)}';
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration:
                      Duration(milliseconds: 220 + ((i - 1) % 8) * 35),
                  curve: AppTheme.curve,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, (1 - v) * 14),
                      child: child,
                    ),
                  ),
                  child: Pressable(
                    onTap: () => _resume(e),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.045),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.stroke),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 84,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: Icon(
                                  e.isTv
                                      ? Icons.tv_rounded
                                      : Icons.movie_rounded,
                                  color: AppTheme.accent,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(e.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.text)),
                                const SizedBox(height: 5),
                                Text(sub,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textDim)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 4.5,
                                    backgroundColor: Colors.white
                                        .withOpacity(0.12),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppTheme.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.glowShadow,
                            ),
                            child: IconButton(
                              onPressed: () => _resume(e),
                              icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppTheme.onAccent,
                                  size: 22),
                              tooltip: 'Resume',
                            ),
                          ),
                          IconButton(
                            onPressed: () => _remove(e),
                            icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.textFaint,
                                size: 20),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
