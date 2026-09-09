import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/bridge/host_bridge.dart';
import '../core/runtime/app_runtime.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../providers/stremio_provider.dart';
import '../streaming/torrserver_backend.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// In-place source picker: the professional replacement for a whole
/// separate results page. The caller awaits the chosen [StreamResult]
/// (or null on dismiss) and pushes the player itself.
Future<StreamResult?> showSourcePicker({
  required BuildContext context,
  required MediaItem item,
  required int season,
  required int episode,
}) {
  return showModalBottomSheet<StreamResult?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SourcePickerSheet(
      item: item,
      season: season,
      episode: episode,
    ),
  );
}

class _SourcePickerSheet extends StatefulWidget {
  final MediaItem item;
  final int season;
  final int episode;

  const _SourcePickerSheet({
    required this.item,
    required this.season,
    required this.episode,
  });

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  late final AppRuntime _rt;
  StreamSubscription<AppState>? _sub;

  bool get _isTv => widget.item.mediaType == 'tv';

  @override
  void initState() {
    super.initState();
    final backend = TorrServerBackend();
    _rt = AppRuntime(
      discovery: StremioStreamProvider(),
      engine: backend,
      server: backend,
      bridge: PluginHostBridge(),
    );
    _sub = _rt.states.listen((_) {
      if (mounted) setState(() {});
    });
    _rt.dispatch(DiscoverStreams(
      item: widget.item,
      season: widget.season,
      episode: widget.episode,
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rt.dispose();
    super.dispose();
  }

  String get _contextLabel {
    if (!_isTv) return 'Movie';
    final s = widget.season.toString().padLeft(2, '0');
    final e = widget.episode.toString().padLeft(2, '0');
    return 'S$s E$e';
  }

  @override
  Widget build(BuildContext context) {
    final discovery = _rt.state.discovery;
    final loading = discovery.status == DiscoveryStatus.loading;
    final results = discovery.streams;
    final count = results.length;
    final subtitle = loading
        ? 'Finding sources…'
        : '$count source${count == 1 ? '' : 's'} • $_contextLabel';

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: widget.item.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: widget.item.posterPath!,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              fadeInDuration: AppTheme.fast,
                            )
                          : const Center(
                              child: Icon(Icons.movie_outlined,
                                  color: AppTheme.textDim, size: 22),
                            ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.text)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (loading)
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            else
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: count > 0
                                      ? AppTheme.accent
                                      : AppTheme.textFaint,
                                ),
                              ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(subtitle,
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
                  const SizedBox(width: 8),
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
              const SizedBox(height: 14),
              Expanded(
                child: loading && results.isEmpty
                    ? _loadingList()
                    : results.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).padding.bottom),
                            itemCount: results.length,
                            itemBuilder: (c, i) =>
                                _row(results[i], i < 3),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) => const Row(
        children: [
          ShimmerBox(width: 56, height: 56, radius: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 14, radius: 6),
                SizedBox(height: 8),
                ShimmerBox(width: 170, height: 11, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.stroke),
            ),
            child: const Icon(Icons.cloud_off_outlined,
                size: 34, color: AppTheme.textDim),
          ),
          const SizedBox(height: 12),
          const Text('No streams found',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                  fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Try another episode or add more add-ons.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textDim, fontSize: 12.5)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _rt.dispatch(const RetryDiscovery()),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _row(StreamResult r, bool best) {
    return Pressable(
      onTap: () => Navigator.pop(context, r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: best
              ? AppTheme.accent.withOpacity(0.07)
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: best
                  ? AppTheme.accent.withOpacity(0.35)
                  : AppTheme.stroke),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kindColor(r.kind).withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(_kindIcon(r.kind),
                  color: _kindColor(r.kind), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (best)
                        Container(
                          margin: const EdgeInsets.only(right: 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text('BEST',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.onAccent,
                                  letterSpacing: 0.6)),
                        ),
                      Expanded(
                        child: Text(r.sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                                fontSize: 14.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(r.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textDim, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _pill(r.kind),
                if (r.subtitles.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _ccChip(r.subtitles.length),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _kindColor(StreamKind k) => switch (k) {
        StreamKind.http => AppTheme.accent,
        StreamKind.hls => AppTheme.info,
        StreamKind.torrent => AppTheme.warn,
        StreamKind.external => const Color(0xFF9AA9BD),
      };

  IconData _kindIcon(StreamKind k) => switch (k) {
        StreamKind.http => Icons.bolt_rounded,
        StreamKind.hls => Icons.live_tv_rounded,
        StreamKind.torrent => Icons.cloud_download_rounded,
        StreamKind.external => Icons.open_in_new_rounded,
      };

  Widget _pill(StreamKind k) {
    final c = _kindColor(k);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(k.name.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.6)),
    );
  }

  Widget _ccChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.info.withOpacity(0.4)),
      ),
      child: Text(count > 1 ? 'CC $count' : 'CC',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.info,
              letterSpacing: 0.6)),
    );
  }
}
