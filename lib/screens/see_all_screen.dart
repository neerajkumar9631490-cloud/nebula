import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/stremio/addon_cache.dart';
import '../services/stremio/addon_client.dart';
import '../services/stremio/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';

/// Full-category grid behind every home "SEE ALL" button.
///
/// Shows the plugin's own filter options (e.g. genre chips from the
/// manifest's `extra` block) and pages further results with `skip`
/// as you scroll — only when the manifest declares them.
class SeeAllScreen extends StatefulWidget {
  final CatalogSection section;

  const SeeAllScreen({super.key, required this.section});

  @override
  State<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends State<SeeAllScreen> {
  final AddonClient _client = AddonClient();
  final ScrollController _scroll = ScrollController();

  late List<MediaItem> _items;
  final Map<String, String> _selected = {};
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _gen = 0;

  /// Option filters declared by the manifest (genre, …).
  /// 'search'/'skip' are transport mechanics, not visible filters.
  List<AddonCatalogExtra> get _filters => widget.section.catalog.extra
      .where((e) =>
          e.options.isNotEmpty && e.name != 'search' && e.name != 'skip')
      .toList();

  bool get _skipSupported =>
      widget.section.catalog.extra.any((e) => e.name == 'skip');

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.section.items);
    _hasMore = _skipSupported && _items.isNotEmpty;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    if (_scroll.position.pixels >= max - 600) _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final gen = ++_gen;
    setState(() {
      if (reset) {
        _loading = true;
        _items = [];
      } else {
        _loadingMore = true;
      }
    });
    try {
      final params = <String, String>{
        ...widget.section.catalog.requiredDefaults,
        ..._selected,
        if (!reset && _skipSupported) 'skip': '${_items.length}',
      };
      final batch = await _client
          .fetchCatalog(
            baseUrl: widget.section.baseUrl,
            type: widget.section.catalog.type,
            catalogId: widget.section.catalog.id,
            extra: params,
            client: AddonCache.instance.client,
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted || gen != _gen) return;
      setState(() {
        if (reset) {
          _items = batch;
          _loading = false;
        } else {
          _items = [..._items, ...batch];
          _loadingMore = false;
        }
        if (batch.isEmpty) _hasMore = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _pick(String name, String? option) {
    setState(() {
      if (option == null) {
        _selected.remove(name);
      } else {
        _selected[name] = option;
      }
      _hasMore = _skipSupported;
    });
    _fetch(reset: true);
  }

  void _open(BuildContext context, MediaItem item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      );

  String _prettyName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final filters = _filters;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.section.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in filters) _filterBlock(f),
          if (_loadingMore)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, 32 + MediaQuery.of(context).padding.bottom),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2 / 3,
                    ),
                    itemCount: 9,
                    itemBuilder: (c, i) => AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ShimmerBox(
                        width: double.infinity,
                        height: double.infinity,
                        radius: 18,
                      ),
                    ),
                  )
                : GridView.builder(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, 32 + MediaQuery.of(context).padding.bottom),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2 / 3,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (c, i) =>
                        TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration:
                          Duration(milliseconds: 220 + (i % 9) * 35),
                      curve: AppTheme.curve,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 16),
                          child: child,
                        ),
                      ),
                      child: Pressable(
                        onTap: () => _open(context, _items[i]),
                        child: PosterTile(item: _items[i], radius: 18),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBlock(AddonCatalogExtra f) {
    final sel = _selected[f.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(_prettyName(f.name),
              style: const TextStyle(
                  color: AppTheme.textDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: f.options.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (c, i) {
              final isAll = i == 0;
              final opt = isAll ? null : f.options[i - 1];
              final active = isAll ? sel == null : sel == opt;
              return Pressable(
                onTap: () => _pick(f.name, opt),
                child: AnimatedContainer(
                  duration: AppTheme.fast,
                  curve: AppTheme.curve,
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: active ? AppTheme.accentGradient : null,
                    color: active
                        ? null
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                        color: active
                            ? Colors.transparent
                            : AppTheme.stroke),
                  ),
                  child: Text(isAll ? 'All' : opt!,
                      style: TextStyle(
                          color: active
                              ? AppTheme.onAccent
                              : AppTheme.textDim,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
