import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../models/stream_result.dart';
import '../services/tmdb_service.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
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

  @override
  void dispose() {
    _seasonCtrl.dispose();
    _episodeCtrl.dispose();
    super.dispose();
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
        setState(() => _status
            .add('TMDB resolved ${imdbId.isEmpty ? "no external id" : imdbId}'));
      }
    } catch (e) {
      if (mounted) setState(() => _status.add('TMDB lookup failed'));
    }

    final urls = await AddonManager.getManifestUrls();
    if (urls.isEmpty && mounted) {
      setState(() => _status.add('No add-ons installed yet.'));
    }

    final futures = <Future<void>>[];
    for (final url in urls) {
      futures.add(Future(() async {
        final base = AddonManager.baseUrlFromManifestUrl(url);
        try {
          final manifest = await _client.fetchManifest(url);
          if (!manifest.supportsStream) {
            if (mounted) {
              setState(() => _status.add('${manifest.name}: no stream resource'));
            }
            return;
          }
          final stremioType = _isTv ? 'series' : 'movie';
          if (manifest.types.isNotEmpty && !manifest.types.contains(stremioType)) {
            if (mounted) {
              setState(() => _status.add('${manifest.name}: skips $stremioType'));
            }
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
              // Best quality first for a premium feel.
              streams.sort((a, b) => b.label.compareTo(a.label));
              _results.addAll(streams);
              _status.add('${manifest.name}: ${streams.length} found');
            });
          }
        } catch (e) {
          if (mounted) setState(() => _status.add('$base: unreachable'));
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
            title: _isTv
                ? '${widget.item.title} • S${_season}E${_episode}'
                : widget.item.title,
            item: widget.item,
            season: _isTv ? _season : null,
            episode: _isTv ? _episode : null,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This source type is not supported yet.')),
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
              fontSize: 10, fontWeight: FontWeight.w800, color: c, letterSpacing: 0.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
            Text(
                _isTv ? 'Season $_season • Episode $_episode' : 'Movie • All sources',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textDim, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension_outlined),
            tooltip: 'Manage add-ons',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddonsScreen()));
              _run();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
                icon: AnimatedRotation(
                  turns: _loading ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: const Icon(Icons.refresh_rounded),
                ),
                onPressed: _loading ? null : _run),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isTv)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: GlassCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.tv_rounded,
                        color: AppTheme.textDim, size: 19),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      child: TextField(
                        controller: _seasonCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppTheme.text, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'S'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('×', style: TextStyle(color: AppTheme.textDim)),
                    ),
                    SizedBox(
                      width: 52,
                      child: TextField(
                        controller: _episodeCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppTheme.text, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                            isDense: true, hintText: 'E'),
                      ),
                    ),
                    const Spacer(),
                    Pressable(
                      onTap: _loading ? null : _run,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Load',
                            style: TextStyle(
                                color: AppTheme.onAccent,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                GlassCard(
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: AppTheme.med,
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _loading
                                  ? AppTheme.warn
                                  : (_results.isEmpty
                                      ? AppTheme.danger
                                      : AppTheme.accent),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(
                              _loading
                                  ? 'Scanning sources…'
                                  : 'Scan complete • ${_results.length} streams',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.text,
                                  fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_status.isEmpty)
                        const Text('Contacting add-ons…',
                            style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
                      ..._status.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(Icons.circle,
                                      size: 6, color: AppTheme.textFaint),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(s,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.textDim,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                          )),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(minHeight: 3.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Results (${_results.length})',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text)),
                const SizedBox(height: 12),
                if (_results.isEmpty && !_loading)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cloud_off_outlined,
                            size: 38, color: AppTheme.textFaint),
                        SizedBox(height: 10),
                        Text('No streams found',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: AppTheme.text)),
                        SizedBox(height: 4),
                        Text('Try another episode or add more add-ons.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textDim, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ..._results.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final best = i < 3;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 240 + (i % 10) * 35),
                    curve: AppTheme.curve,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                          offset: Offset(0, (1 - v) * 14), child: child),
                    ),
                    child: Pressable(
                      onTap: () => _onTapResult(r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: best
                              ? AppTheme.accent.withOpacity(0.07)
                              : Colors.white.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: best
                                  ? AppTheme.accent.withOpacity(0.35)
                                  : AppTheme.stroke),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _kindColor(r.kind).withOpacity(0.13),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_kindIcon(r.kind),
                                color: _kindColor(r.kind), size: 20),
                          ),
                          title: Row(
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
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(r.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textDim, fontSize: 12.5)),
                          ),
                          trailing: _pill(r.kind),
                          onTap: () => _onTapResult(r),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
