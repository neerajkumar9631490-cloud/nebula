import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/watch_progress_service.dart';
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
  Map<String, WatchProgress> _episodeProgress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (widget.item.mediaType == 'tv') {
      // For TV, we just load progress when user taps an episode
    } else {
      final p = await _wp.loadMovie(widget.item.id);
      if (mounted) setState(() => _movieProgress = p);
    }
  }

  Future<WatchProgress?> _getEpisodeProgress(int season, int episode) async {
    return _wp.loadEpisode(widget.item.id, season, episode);
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

  Widget _progressBar(WatchProgress p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: p.durationMs > 0 ? (p.positionMs / p.durationMs) : 0,
          backgroundColor: Colors.white24,
          color: Colors.orange,
        ),
        const SizedBox(height: 4),
        Text(
          'Progress: ${p.positionLabel} (${p.progressPercent.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = TMDBService(widget.apiKey);
    final isTv = widget.item.mediaType == 'tv';

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                height: 300,
                child: widget.item.posterPath != null
                    ? CachedNetworkImage(imageUrl: service.getImgUrl(widget.item.posterPath))
                    : const Icon(Icons.movie, size: 100),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${widget.item.releaseYear} • ${widget.item.mediaType.toUpperCase()}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.item.overview.isEmpty ? 'No overview available.' : widget.item.overview),
            const SizedBox(height: 24),

            if (!isTv && _movieProgress != null && _movieProgress!.isResumable) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.play_circle, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Continue Watching',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _progressBar(_movieProgress!),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _openSources,
                          icon: const Icon(Icons.play_arrow),
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
              Row(
                children: [
                  const Text('Season: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _selectedSeason,
                    items: List.generate(5, (i) => i + 1)
                        .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSeason = v ?? 1),
                  ),
                  const SizedBox(width: 16),
                  const Text('Episode: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _selectedEpisode,
                    items: List.generate(20, (i) => i + 1)
                        .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedEpisode = v ?? 1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(isTv ? 'Find Sources (S${_selectedSeason}E${_selectedEpisode})' : 'Find Sources'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: _openSources,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
