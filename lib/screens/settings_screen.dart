import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../music/player/music_player_controller.dart';
import '../music/services/music_settings.dart';
import '../services/stremio/addon_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'addons_screen.dart';

/// Settings in an editorial premium style: oversized display header,
/// hero status card, grouped rows with rounded icon tiles and tracked
/// eyebrow labels — deliberately different from the card-grid voice
/// used on Home and Discover.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _addonCount = 0;
  bool _clearing = false;
  MusicAudioSource _audioSource = MusicAudioSource.flac;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _loadAudioSource();
  }

  Future<void> _refreshCount() async {
    final urls = await AddonManager.getManifestUrls();
    if (mounted) setState(() => _addonCount = urls.length);
  }

  Future<void> _loadAudioSource() async {
    await MusicSettings.instance.ensureLoaded();
    if (mounted) {
      setState(() => _audioSource = MusicSettings.instance.source);
    }
  }

  Future<void> _setAudioSource(MusicAudioSource source) async {
    setState(() => _audioSource = source);
    // Routes through the player controller so the current track
    // reloads seamlessly when one is playing.
    await MusicPlayerController().setAudioSource(source);
    if (mounted) setState(() => _audioSource = MusicSettings.instance.source);
  }

  Future<void> _openPlugins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddonsScreen()),
    );
    _refreshCount();
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      if (k == 'recent_searches' ||
          k.startsWith('wp_movie_') ||
          k.startsWith('wp_tv_')) {
        await prefs.remove(k);
      }
    }
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cleared recents and watch progress.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 110 + bottom),
          children: [
            const Text('Settings', style: AppTheme.display),
            const SizedBox(height: 4),
            const Text(
              'Tune Movix your way',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDim,
                  fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 18),
            _heroCard(),
            const SizedBox(height: 26),
            _eyebrow('Streaming'),
            const SizedBox(height: 10),
            _group([
              _row(
                icon: Icons.extension_rounded,
                tint: AppTheme.accent,
                title: 'Plugins / Add-ons',
                subtitle: _addonCount == 0
                    ? 'No plugins installed'
                    : '$_addonCount plugin${_addonCount == 1 ? '' : 's'} installed',
                trailing: const _Chevron(),
                onTap: _openPlugins,
              ),
              _row(
                icon: Icons.bolt_rounded,
                tint: AppTheme.warn,
                title: 'Find sources faster',
                subtitle: 'Install trusted Stremio manifests',
                trailing: const _Chevron(),
                onTap: _openPlugins,
              ),
            ]),
            const SizedBox(height: 26),
            _eyebrow('Catalog'),
            const SizedBox(height: 10),
            _group([
              _row(
                icon: Icons.grid_view_rounded,
                tint: AppTheme.info,
                title: 'Catalog source',
                subtitle: 'Cinemeta • Top Movies & Series included',
                trailing: const Icon(Icons.verified_rounded,
                    color: AppTheme.accent, size: 20),
              ),
              _row(
                icon: Icons.refresh_rounded,
                tint: AppTheme.textDim,
                title: 'Reload categories',
                subtitle: 'Refresh rows from your plugins',
                trailing: const _Chevron(),
                onTap: _openPlugins,
              ),
            ]),
            const SizedBox(height: 26),
            _eyebrow('Playback'),
            const SizedBox(height: 10),
            _group([
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _iconTile(
                            Icons.high_quality_rounded, AppTheme.accent),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Music quality',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.text,
                                      fontSize: 15)),
                              SizedBox(height: 2),
                              Text(
                                'Lossless FLAC or YouTube HQ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<MusicAudioSource>(
                      showSelectedIcon: false,
                      expandedInsets: EdgeInsets.zero,
                      style: SegmentedButton.styleFrom(
                        side:
                            const BorderSide(color: AppTheme.stroke),
                        selectedForegroundColor: AppTheme.onAccent,
                        selectedBackgroundColor: AppTheme.accent,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: MusicAudioSource.flac,
                          icon: Icon(Icons.high_quality_rounded,
                              size: 18),
                          label: Text('FLAC lossless'),
                        ),
                        ButtonSegment(
                          value: MusicAudioSource.youtube,
                          icon: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 18),
                          label: Text('YouTube HQ'),
                        ),
                      ],
                      selected: {_audioSource},
                      onSelectionChanged: (s) =>
                          _setAudioSource(s.first),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 26),
            _eyebrow('Storage'),
            const SizedBox(height: 10),
            _group([
              _row(
                icon: Icons.cleaning_services_outlined,
                tint: AppTheme.textDim,
                title: 'Clear recents & progress',
                subtitle: 'Search history and resume points',
                trailing: _clearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                    : const _Chevron(),
                onTap: _clearing ? null : _clearCache,
              ),
            ]),
            const SizedBox(height: 26),
            _eyebrow('About'),
            const SizedBox(height: 10),
            _aboutCard(),
            const SizedBox(height: 20),
            const Center(
              child: Text('Movix v1.1.0 • Every stream. One app.',
                  style:
                      TextStyle(color: AppTheme.textFaint, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pieces ─────────────────────────────────────────────

  Widget _eyebrow(String s) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(s.toUpperCase(), style: AppTheme.eyebrow),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7A42), Color(0xFF0B1F15), Color(0xFF0A1420)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          const AppLogo(size: 58, radius: 17),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOVIX',
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 5,
                        color: Colors.white)),
                SizedBox(height: 5),
                Text('Universal media aggregator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Text('v1.1.0',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    final separated = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      separated.add(rows[i]);
      if (i < rows.length - 1) {
        separated.add(const Divider(
            height: 1, indent: 67, endIndent: 0));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: separated,
      ),
    );
  }

  Widget _iconTile(IconData icon, Color tint) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: tint, size: 21),
    );
  }

  Widget _row({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            child: Row(
              children: [
                _iconTile(icon, tint),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textDim)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.5),
                      width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/developer_logo.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (c, e, s) => Container(
                      color: AppTheme.accent,
                      alignment: Alignment.center,
                      child: const Text('N',
                          style: TextStyle(
                              color: AppTheme.onAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neeraj',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text)),
                    SizedBox(height: 2),
                    Text('Creator & Developer',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 13, color: AppTheme.accent),
                    SizedBox(width: 4),
                    Text('OFFICIAL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.accent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Text(
            'Designed and crafted with care by Neeraj — a fast, cinematic home for your movies, shows and anime.',
            style: TextStyle(
                color: AppTheme.textDim, fontSize: 13.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right_rounded,
        color: AppTheme.textFaint, size: 22);
  }
}
