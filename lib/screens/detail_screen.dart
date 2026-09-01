import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/watch_progress_service.dart';
import '../theme/app_theme.dart';
import 'sources_screen.dart';

class DetailScreen extends StatefulWidget {
  final MediaItem item;
  final String apiKey;

  const DetailScreen({super.key, required this.item, required this.apiKey});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final WatchProgressService _wp = WatchProgressService();
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  WatchProgress? _movieProgress;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (widget.item.mediaType != 'tv') {
      final p = await _wp.loadMovie(widget.item.id);
      if (mounted) setState(() => _movieProgress = p);
    }
  }

  void _openSources() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SourcesScreen(
          item: widget.item,
          apiKey: widget.apiKey,
          season: _selectedSeason,
          episode: _selectedEpisode,
        ),
      ),
    ).then((_) => _loadProgress());
  }

  Widget _chip(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.warn),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = TMDBService(widget.apiKey);
    final isTv = widget.item.mediaType == 'tv';
    final backdrop = widget.item.backdropPath != null
        ? service.getImgUrl(widget.item.backdropPath)
        : (widget.item.posterPath != null ? service.getImgUrl(widget.item.posterPath) : null);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 300,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop != null)
                        CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover, memCacheWidth: 900),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.bg.withOpacity(0.2),
                              AppTheme.bg.withOpacity(0.7),
                              AppTheme.bg,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -70),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 118,
                              height: 177,
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.stroke),
                                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: widget.item.posterPath != null
                                    ? CachedNetworkImage(imageUrl: service.getImgUrl(widget.item.posterPath), fit: BoxFit.cover)
                                    : const Center(child: Icon(Icons.movie_outlined, size: 44, color: AppTheme.textDim)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.item.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.text, height: 1.2),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _chip(widget.item.releaseYear),
                                        _chip(widget.item.mediaType.toUpperCase()),
                                        if (widget.item.rating > 0)
                                          _chip(widget.item.rating.toStringAsFixed(1), icon: Icons.star_rounded),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.overview.isEmpty ? 'No overview available.' : widget.item.overview,
                        style: const TextStyle(color: AppTheme.textDim, height: 1.5),
                      ),
                      const SizedBox(height: 20),

                      if (!isTv && _movieProgress != null && _movieProgress!.isResumable) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.play_circle_rounded, color: AppTheme.warn),
                                  SizedBox(width: 8),
                                  Text('Continue Watching', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: _movieProgress!.durationMs > 0 ? (_movieProgress!.positionMs / _movieProgress!.durationMs) : 0,
                                backgroundColor: AppTheme.cardHi,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warn),
                                minHeight: 5,
                              ),
                              const SizedBox(height: 6),
                              Text('Watched ${_movieProgress!.positionLabel}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _openSources,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Resume'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      await _wp.clearMovie(widget.item.id);
                                      setState(() => _movieProgress = null);
                                    },
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (isTv) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.stroke),
                          ),
                          child: Row(
                            children: [
                              const Text('Season ', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text)),
                              DropdownButton<int>(
                                value: _selectedSeason,
                                dropdownColor: AppTheme.cardHi,
                                style: const TextStyle(color: AppTheme.text),
                                underline: const SizedBox.shrink(),
                                items: List.generate(5, (i) => i + 1)
                                    .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedSeason = v ?? 1),
                              ),
                              const SizedBox(width: 20),
                              const Text('Episode ', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text)),
                              DropdownButton<int>(
                                value: _selectedEpisode,
                                dropdownColor: AppTheme.cardHi,
                                style: const TextStyle(color: AppTheme.text),
                                underline: const SizedBox.shrink(),
                                items: List.generate(20, (i) => i + 1)
                                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedEpisode = v ?? 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openSources,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(isTv ? 'Find Sources  •  S${_selectedSeason}E${_selectedEpisode}' : 'Find Sources'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
