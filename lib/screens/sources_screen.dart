import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../services/tmdb_service.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';
import 'addons_screen.dart';
import 'player_screen.dart';

class SourcesScreen extends StatefulWidget {
  final MediaItem item;
  final String apiKey;

  const SourcesScreen({super.key, required this.item, required this.apiKey});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final AddonClient _client = AddonClient();
  final List<StreamResult> _results = [];
  final List<String> _status = [];
  bool _loading = true;
  final TextEditingController _seasonCtrl = TextEditingController(text: '1');
  final TextEditingController _episodeCtrl = TextEditingController(text: '1');

  bool get _isTv => widget.item.mediaType == 'tv';
  int get _season => int.tryParse(_seasonCtrl.text) ?? 1;
  int get _episode => int.tryParse(_episodeCtrl.text) ?? 1;

  @override
  void initState() {
    super.initState();
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
      if (mounted) {
        setState(() => _status.add('TMDB: imdb id = ${imdbId.isEmpty ? "not found" : imdbId}'));
      }
    } catch (e) {
      if (mounted) setState(() => _status.add('TMDB external_ids failed: $e'));
    }

    final urls = await AddonManager.getManifestUrls();
    if (urls.isEmpty && mounted) {
      setState(() => _status.add('No add-ons installed (use the puzzle icon to add one).'));
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

  Future<void> _onTapResult(StreamResult r) async {
    if (r.playable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(result: r, title: widget.item.title),
        ),
      );
      return;
    }
    
    if (r.isTorrent && r.magnet != null) {
      // Open magnet in external torrent app
      final uri = Uri.parse(r.magnet!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No torrent app installed. Install LibreTorrent or Flud.')),
        );
      }
      return;
    }
    
    if (r.kind == StreamKind.external && r.url != null) {
      final uri = Uri.parse(r.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This source type is not supported.')),
    );
  }

  Color _kindColor(StreamKind k) => switch (k) {
        StreamKind.http => Colors.green,
        StreamKind.hls => Colors.teal,
        StreamKind.torrent => Colors.orange,
        StreamKind.external => Colors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sources: ${widget.item.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: 'Manage add-ons',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddonsScreen()));
              _run();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _run),
        ],
      ),
      body: Column(
        children: [
          if (_isTv)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('S/E:'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _seasonCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _episodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: _run, child: const Text('Re-run')),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Source status', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (_status.isEmpty) const Text('Querying sources...'),
                      ..._status.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          )),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Results (${_results.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_results.isEmpty && !_loading)
                  const Text('No streams found. Add add-ons via the puzzle icon, or check status above.'),
                ..._results.map((r) => Card(
                      child: ListTile(
                        leading: Icon(
                          r.kind == StreamKind.hls ? Icons.live_tv : 
                          r.kind == StreamKind.torrent ? Icons.cloud_download :
                          Icons.play_circle_outline,
                          color: _kindColor(r.kind),
                        ),
                        title: Text(r.sourceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(r.label, maxLines: 3, overflow: TextOverflow.ellipsis),
                        trailing: Chip(
                          label: Text(r.kind.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        ),
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
