import 'package:flutter/material.dart';
import '../core/runtime/app_target.dart';
import '../models/media_item.dart';
import '../services/stremio/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import 'addons_screen.dart';
import 'detail_screen.dart';
import 'see_all_screen.dart';

/// Reference-style home: logo + search pill on top, then bold
/// title rows with SEE ALL and edge-to-edge poster tiles.
/// Categories come from the installed catalog plugins.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearchTap;

  const HomeScreen({super.key, this.onSearchTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final CatalogService _catalogs = CatalogService();
  late Future<List<CatalogSection>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Cached sections paint instantly; the network refresh lands
    // via onRefresh without a second spinner.
    _future = _catalogs.loadSectionsCached(onRefresh: (fresh) async {
      if (mounted) setState(() => _future = Future.value(fresh));
    });
  }

  void _refresh() => setState(() => _future = _catalogs.loadSections());

  void _open(MediaItem item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      );

  void _seeAll(CatalogSection section) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeeAllScreen(section: section),
        ),
      );

  Future<void> _openPlugins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddonsScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: FutureBuilder<List<CatalogSection>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingBody();
                }
                if (snapshot.hasError) {
                  return _errorState('Home could not load');
                }
                final sections = snapshot.data ?? [];
                if (sections.isEmpty) {
                  return _emptyState();
                }
                return RefreshIndicator(
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surface,
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.only(
                        bottom:
                            110 + MediaQuery.of(context).padding.bottom),
                    itemCount: sections.length,
                    itemBuilder: (c, i) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHead(sections[i]),
                        _posterRow(sections[i].items),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            const AppLogo(size: 52, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Pressable(
                onTap: widget.onSearchTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D26),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'You can search anything...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textDim, fontSize: 15),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.search_rounded,
                          color: AppTheme.textDim, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHead(CatalogSection s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sectionTitle),
                const SizedBox(height: 3),
                Text(s.subtitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.eyebrow),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _seeAll(s),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textDim,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SEE ALL',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterRow(List<MediaItem> items) {
    return RepaintBoundary(
      child: SizedBox(
        height: 207,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // Staggered TweenAnimationBuilders used to rebuild every tile
          // for ~600ms on each paint (jank on scroll). Tiles now paint
          // once; images fade in via CachedNetworkImage instead.
          cacheExtent: 600,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (c, i) => Pressable(
            autofocus: AppTarget.isTv && i == 0,
            onTap: () => _open(items[i]),
            child: PosterTile(item: items[i]),
          ),
        ),
      ),
    );
  }

  Widget _loadingBody() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
          bottom: 110 + MediaQuery.of(context).padding.bottom),
      children: [
        for (var s = 0; s < 3; s++) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: ShimmerBox(width: 220, height: 22, radius: 8),
          ),
          SizedBox(
            height: 207,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (c, i) =>
                  const ShimmerBox(width: 138, height: 207, radius: 22),
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
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
              child: const Icon(Icons.extension_off_rounded,
                  size: 40, color: AppTheme.textDim),
            ),
            const SizedBox(height: 16),
            const Text('No categories yet',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text)),
            const SizedBox(height: 6),
            const Text(
                'Install a catalog plugin to browse movies and series.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textDim, fontSize: 13.5)),
            const SizedBox(height: 20),
            Pressable(
              onTap: _openPlugins,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.glowShadow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension_rounded,
                        color: AppTheme.onAccent, size: 19),
                    SizedBox(width: 8),
                    Text('Browse plugins',
                        style: TextStyle(
                            color: AppTheme.onAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 44, color: AppTheme.warn),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ],
      ),
    );
  }
}
