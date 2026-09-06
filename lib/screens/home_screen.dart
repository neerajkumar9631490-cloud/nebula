import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/stremio/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';
import 'addons_screen.dart';
import 'detail_screen.dart';

/// Home lists movie & series categories provided by the installed
/// catalog plugins — no API key needed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogService _catalogs = CatalogService();
  late Future<List<CatalogSection>> _future;

  final PageController _heroCtrl = PageController(viewportFraction: 1.0);
  int _heroIndex = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _future = _catalogs.loadSections();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    _heroTimer?.cancel();
    setState(() {
      _heroIndex = 0;
      _future = _catalogs.loadSections();
    });
  }

  void _startHeroAutoplay(int count) {
    _heroTimer?.cancel();
    if (count <= 1) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_heroCtrl.hasClients || !mounted) return;
      final next = (_heroIndex + 1) % count;
      _heroCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 650), curve: AppTheme.curve);
    });
  }

  void _open(MediaItem item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      );

  Future<void> _openPlugins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddonsScreen()),
    );
    _refresh();
  }

  // ── Hero carousel ──────────────────────────────────────────
  Widget _heroCarousel(List<MediaItem> items, String label) {
    final heroes = items.take(6).toList();
    if (heroes.isEmpty) return const SizedBox.shrink();
    _startHeroAutoplay(heroes.length);
    return RepaintBoundary(
      child: SizedBox(
        height: 470,
        child: Stack(
          children: [
            PageView.builder(
              controller: _heroCtrl,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (i) => setState(() => _heroIndex = i),
              itemCount: heroes.length,
              itemBuilder: (c, i) =>
                  _heroSlide(heroes[i], i == _heroIndex, label),
            ),
            // Bottom fade is baked into each slide via heroScrim; indicators float above.
            Positioned(
              left: 20,
              right: 20,
              bottom: 10,
              child: Row(
                children: [
                  ...List.generate(
                    heroes.length,
                    (i) => AnimatedContainer(
                      duration: AppTheme.med,
                      curve: AppTheme.curve,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _heroIndex ? 26 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: i == _heroIndex
                            ? AppTheme.accent
                            : Colors.white.withOpacity(0.28),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Text('${_heroIndex + 1} / ${heroes.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSlide(MediaItem item, bool active, String label) {
    final backdrop = item.backdropPath;
    return GestureDetector(
      onTap: () => _open(item),
      child: AnimatedScale(
        scale: active ? 1.0 : 0.97,
        duration: AppTheme.slow,
        curve: AppTheme.curve,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null)
              CachedNetworkImage(
                imageUrl: backdrop,
                fit: BoxFit.cover,
                memCacheWidth: 1000,
                filterQuality: FilterQuality.high,
                fadeInDuration: AppTheme.med,
                placeholder: (c, u) => Container(color: AppTheme.bgHi),
                errorWidget: (c, u, e) => Container(
                  color: AppTheme.bgHi,
                  child: const Center(
                      child: Icon(Icons.movie_outlined,
                          size: 56, color: AppTheme.textFaint)),
                ),
              )
            else
              Container(color: AppTheme.bgHi),
            const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.heroScrim)),
            Positioned(
              left: 20,
              right: 20,
              bottom: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 13, color: AppTheme.accentHi),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '#${_heroIndex + 1} ${label.toUpperCase()} • ${item.mediaType.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.accentHi,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.star),
                        const SizedBox(width: 4),
                        Text(item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.white54)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          item.releaseYear.isEmpty
                              ? item.mediaType.toUpperCase()
                              : '${item.releaseYear}  •  ${item.mediaType.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  if (item.overview.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Pressable(
                        onTap: () => _open(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.glowShadow,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: AppTheme.onAccent, size: 20),
                              SizedBox(width: 6),
                              Text('Watch Now',
                                  style: TextStyle(
                                      color: AppTheme.onAccent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () => _open(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.22)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Details',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterRow(List<MediaItem> items, {bool ranked = false}) {
    return RepaintBoundary(
      child: SizedBox(
        height: 252,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 13),
          itemBuilder: (c, i) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 260 + (i % 8) * 40),
            curve: AppTheme.curve,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 18),
                child: child,
              ),
            ),
            child: SizedBox(
              width: 134,
              child: Pressable(
                onTap: () => _open(items[i]),
                child: PosterCard(
                  item: items[i],
                  rank: ranked ? i + 1 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<CatalogSection>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                const SliverAppBar(
                  floating: true,
                  title: Text('MOVIX',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 5)),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: double.infinity, height: 430, radius: 0),
                      const SectionHeader(title: 'Loading your cinema'),
                      const PosterRowSkeleton(),
                      const SizedBox(height: 8),
                      const PosterRowSkeleton(count: 4),
                      SizedBox(height: 90 + MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return _errorState('Home could not load');
          }
          final sections = snapshot.data ?? [];
          if (sections.isEmpty) {
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text)),
                    const SizedBox(height: 6),
                    const Text(
                        'Install a catalog plugin to browse movies and series.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                            onPressed: _openPlugins,
                            icon: const Icon(Icons.extension_rounded),
                            label: const Text('Browse plugins')),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          final heroSection = sections.firstWhere(
            (s) => s.isMovies,
            orElse: () => sections.first,
          );
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: AppTheme.bg.withOpacity(0.85),
                  title: const Row(
                    children: [
                      AppLogo(size: 32, radius: 9, glow: false),
                      SizedBox(width: 10),
                      Text('MOVIX',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5)),
                    ],
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: Pressable(
                        onTap: _openPlugins,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.stroke),
                          ),
                          child: const Icon(Icons.extension_outlined,
                              size: 19, color: AppTheme.text),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                    child:
                        _heroCarousel(heroSection.items, heroSection.title)),
                for (var i = 0; i < sections.length; i++)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: sections[i].title,
                          subtitle: sections[i].subtitle,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: AppTheme.med,
                          switchInCurve: AppTheme.curve,
                          child: KeyedSubtree(
                            key: ValueKey(
                                'row-$i-${sections[i].items.length}'),
                            child: _posterRow(sections[i].items,
                                ranked: i == 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: 100 + MediaQuery.of(context).padding.bottom),
                ),
              ],
            ),
          );
        },
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
