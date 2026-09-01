import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../services/tmdb_service.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';
import '../theme/app_theme.dart';
import 'addons_screen.dart';
import 'player_screen.dart';

class SourcesScreen extends StatefulWidget {
  final MediaItem item;
  final String apiKey;
  final int season;
  final int episode;

  const SourcesScreen({
    super.key,
    required this.item,
    required this.apiKey,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final AddonClient _client = AddonClient();
  final List<StreamResult> _results = [];
  final List<String> _status = [];
  bool _loading = true;
  late TextEditingController _seasonCtrl;
  late TextEditingController _episodeCtrl;

  bool get _isTv => widget.item.mediaType == 'tv';
  int get _season => int.tryParse(_seasonCtrl.text) ?? 1;
  int get _episode => int.tryParse(_episodeCtrl.text) ?? 1;

  @override
  void initState() {
    super.initState();
    _seasonCtrl = TextEditingController(text: widget.season.toString());
    _episodeCtrl = TextEditingController(text: widget.episode.toString());
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _results.clear();
      _status.clear();
    });

    final tmdb = TMDBService(widget.apiKey);
    String imdbId = '';
    try {
      imdbId = await tmdb.getExternalId(widget.item.mediaType, widget.item.id);
      if (mounted) setState(() => _status.add('TMDB: imdb id = ${imdbId.isEmpty ? "not found" : imdbId}'));
    } catch (e) {
      if (mounted) setState(() => _status.add('TMDB external_ids failed: $e'));
    }

    final urls = await AddonManager.getManifestUrls();
    if (urls.isEmpty && mounted) {
      setState(() => _status.add('No add-ons installed.'));
    }

    final futures = <Future<void>>[];
    for (final url in urls) {
      futures.add(Future(() async {
        final base = AddonManager.baseUrlFromManifestUrl(url);
        try {
          final manifest = await _client.fetchManifest(url);
          if (!manifest.supportsStream) {
            if (mounted) setState(() => _status.add('${manifest.name}: no "stream" resource'));
            return;
          }
          final stremioType = _isTv ? 'series' : 'movie';
          if (manifest.types.isNotEmpty && !manifest.types.contains(stremioType)) {
            if (mounted) setState(() => _status.add('${manifest.name}: does not support $stremioType'));
            return;
          }
          final streams = await _client.queryStreams(
            baseUrl: base,
            addonName: manifest.name,
            mediaType: stremioType,
            imdbId: imdbId,
            tmdbId: widget.item.id.toString(),
            idPrefixes: manifest.idPrefixes,
            season: _season,
            episode: _episode,
          );
          if (mounted) {
            setState(() {
              _results.addAll(streams);
              _status.add('${manifest.name}: ${streams.length} streams');
            });
          }
        } catch (e) {
          if (mounted) setState(() => _status.add('$base: failed ($e)'));
        }
      }));
    }

    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  void _onTapResult(StreamResult r) {
    if (r.playable || r.isTorrent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            result: r,
            title: _isTv ? '${widget.item.title} - S${_season}E${_episode}' : widget.item.title,
            item: widget.item,
            season: _isTv ? _season : null,
            episode: _isTv ? _episode : null,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This source type is not supported.')),
    );
  }

  Color _kindColor(StreamKind k) => switch (k) {
        StreamKind.http => Colors.greenAccent,
        StreamKind.hls => Colors.tealAccent,
        StreamKind.torrent => AppTheme.warn,
        StreamKind.external => Colors.blueAccent,
      };

  Widget _pill(StreamKind k) {
    final c = _kindColor(k);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(k.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension_rounded),
            tooltip: 'Manage add-ons',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddonsScreen()));
              _run();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _run),
        ],
      ),
      body: Column(
        children: [
          if (_isTv)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.stroke),
                ),
                child: Row(
                  children: [
                    const Text('S / E', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _seasonCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _episodeCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(onPressed: _run, child: const Text('Re-run')),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                      const Text('Source status', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text)),
                      const SizedBox(height: 8),
                      if (_status.isEmpty) const Text('Querying sources...', style: TextStyle(color: AppTheme.textDim)),
                      ..._status.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $s', style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                          )),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Results (${_results.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.text)),
                const SizedBox(height: 12),
                if (_results.isEmpty && !_loading)
                  const Text('No streams found.', style: TextStyle(color: AppTheme.textDim)),
                ..._results.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.stroke),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: Icon(
                          r.kind == StreamKind.hls ? Icons.live_tv_rounded :
                          r.kind == StreamKind.torrent ? Icons.cloud_download_rounded :
                          Icons.play_circle_outline_rounded,
                          color: _kindColor(r.kind),
                        ),
                        title: Text(r.sourceName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text)),
                        subtitle: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textDim)),
                        trailing: _pill(r.kind),
                        onTap: () => _onTapResult(r),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
