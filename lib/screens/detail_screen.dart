import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/watch_progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
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

  Widget _chip(String label, {IconData? icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? AppTheme.star),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.text)),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.bg,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null)
                    CachedNetworkImage(
                      imageUrl: backdrop,
                      fit: BoxFit.cover,
                      memCacheWidth: 1000,
                      fadeInDuration: AppTheme.med,
                      placeholder: (c, u) => Container(color: AppTheme.bgHi),
                      errorWidget: (c, u, e) => Container(color: AppTheme.bgHi),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0B1F15), AppTheme.bg],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33070B12),
                          Color(0x99070B12),
                          Color(0xFF070B12),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -64),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Hero(
                          tag: 'poster-${widget.item.id}',
                          child: Container(
                            width: 122,
                            height: 183,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.strokeHi),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: widget.item.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          service.getImgUrl(widget.item.posterPath),
                                      fit: BoxFit.cover,
                                      memCacheWidth: 360,
                                    )
                                  : const Center(
                                      child: Icon(Icons.movie_outlined,
                                          size: 44, color: AppTheme.textDim)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.text,
                                      height: 1.2,
                                      letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    _chip(widget.item.releaseYear.isEmpty
                                        ? widget.item.mediaType.toUpperCase()
                                        : widget.item.releaseYear),
                                    _chip(widget.item.mediaType.toUpperCase()),
                                    if (widget.item.rating > 0)
                                      _chip(widget.item.rating.toStringAsFixed(1),
                                          icon: Icons.star_rounded),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text('Storyline',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.text)),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.overview.isEmpty
                        ? 'No overview available for this title yet.'
                        : widget.item.overview,
                    style: const TextStyle(color: AppTheme.textDim, height: 1.6, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  if (!isTv &&
                      _movieProgress != null &&
                      _movieProgress!.isResumable) ...[
                    GlassCard(
                      radius: 18,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.play_circle_rounded,
                                  color: AppTheme.accent, size: 22),
                              SizedBox(width: 8),
                              Text('Continue Watching',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.text,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _movieProgress!.durationMs > 0
                                  ? (_movieProgress!.positionMs /
                                      _movieProgress!.durationMs)
                                  : 0,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.accent),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Watched ${_movieProgress!.positionLabel} • ${(_movieProgress!.progressPercent).toStringAsFixed(0)}% done',
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppTheme.textDim)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  label: 'Resume',
                                  icon: Icons.play_arrow_rounded,
                                  onTap: _openSources,
                                  expanded: true,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _wp.clearMovie(widget.item.id);
                                  if (mounted) {
                                    setState(() => _movieProgress = null);
                                  }
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
                    GlassCard(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.tv_rounded,
                              color: AppTheme.textDim, size: 20),
                          const SizedBox(width: 12),
                          const Text('S',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: AppTheme.textDim)),
                          const SizedBox(width: 6),
                          DropdownButton<int>(
                            value: _selectedSeason,
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(
                                color: AppTheme.text, fontWeight: FontWeight.w700),
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(14),
                            items: List.generate(5, (i) => i + 1)
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text('$s')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSeason = v ?? 1),
                          ),
                          Container(
                              width: 1,
                              height: 24,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              color: AppTheme.stroke),
                          const Text('E',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: AppTheme.textDim)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButton<int>(
                              value: _selectedEpisode,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(
                                  color: AppTheme.text, fontWeight: FontWeight.w700),
                              underline: const SizedBox.shrink(),
                              borderRadius: BorderRadius.circular(14),
                              isExpanded: true,
                              items: List.generate(20, (i) => i + 1)
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text('Episode $e')))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedEpisode = v ?? 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  GradientButton(
                    label: isTv
                        ? 'Find Sources  •  S${_selectedSeason}E${_selectedEpisode}'
                        : 'Find Sources',
                    icon: Icons.bolt_rounded,
                    onTap: _openSources,
                    expanded: true,
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Streams are resolved via your installed add-ons',
                        style: TextStyle(color: AppTheme.textFaint, fontSize: 12)),
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
