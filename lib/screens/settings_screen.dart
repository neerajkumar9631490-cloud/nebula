import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stremio/addon_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_card.dart';
import 'addons_screen.dart';

/// Professional Settings hub: streaming plugins, API access,
/// storage care, and a crafted About card.
class SettingsScreen extends StatefulWidget {
  final String apiKey;
  final VoidCallback onResetKey;
  final ValueChanged<String> onKeyChanged;

  const SettingsScreen({
    super.key,
    required this.apiKey,
    required this.onResetKey,
    required this.onKeyChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _addonCount = 0;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final urls = await AddonManager.getManifestUrls();
    if (mounted) setState(() => _addonCount = urls.length);
  }

  Future<void> _openPlugins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddonsScreen()),
    );
    _refreshCount();
  }

  void _confirmResetKey() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset TMDB API key?'),
        content: const Text(
            'You will be signed out of the catalog and returned to the setup screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResetKey();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _changeKeyDialog() {
    final ctrl = TextEditingController(text: widget.apiKey);
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('TMDB API key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a valid v3 API key from themoviedb.org.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'API key',
                  errorText: error,
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.length < 10) {
                  setD(() => error = 'That key looks too short.');
                  return;
                }
                Navigator.pop(ctx);
                widget.onKeyChanged(v);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key updated.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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

  String get _maskedKey {
    final k = widget.apiKey;
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings'),
            Text('Tune Movix your way',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, 110 + bottom),
        children: [
          _appCard(),
          const SizedBox(height: 18),
          _sectionLabel('STREAMING'),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  icon: Icons.extension_rounded,
                  iconBg: AppTheme.accent.withOpacity(0.15),
                  iconColor: AppTheme.accent,
                  title: 'Plugins / Add-ons',
                  subtitle: _addonCount == 0
                      ? 'No plugins installed'
                      : '$_addonCount plugin${_addonCount == 1 ? '' : 's'} installed',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textDim),
                  onTap: _openPlugins,
                ),
                const Divider(height: 1, indent: 58),
                _row(
                  icon: Icons.bolt_rounded,
                  iconBg: AppTheme.warn.withOpacity(0.14),
                  iconColor: AppTheme.warn,
                  title: 'Find sources faster',
                  subtitle: 'Install trusted Stremio manifests',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textDim),
                  onTap: _openPlugins,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('ACCOUNT & ACCESS'),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  icon: Icons.vpn_key_rounded,
                  iconBg: AppTheme.info.withOpacity(0.14),
                  iconColor: AppTheme.info,
                  title: 'TMDB API key',
                  subtitle: _maskedKey,
                  trailing: TextButton(
                    onPressed: _changeKeyDialog,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Change'),
                  ),
                ),
                const Divider(height: 1, indent: 58),
                _row(
                  icon: Icons.logout_rounded,
                  iconBg: AppTheme.danger.withOpacity(0.12),
                  iconColor: AppTheme.danger,
                  title: 'Reset API key',
                  subtitle: 'Back to the setup screen',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textDim),
                  onTap: _confirmResetKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('STORAGE'),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: _row(
              icon: Icons.cleaning_services_outlined,
              iconBg: Colors.white.withOpacity(0.07),
              iconColor: AppTheme.textDim,
              title: 'Clear recents & progress',
              subtitle: 'Search history and resume points',
              trailing: _clearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textDim),
              onTap: _clearing ? null : _clearCache,
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel('ABOUT'),
          _aboutCard(),
          const SizedBox(height: 14),
          const Center(
            child: Text('Movix v1.1.0 • Every stream. One app.',
                style: TextStyle(color: AppTheme.textFaint, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _appCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7A42), Color(0xFF0B1F15), Color(0xFF0A1420)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const AppLogo(size: 56, radius: 16),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOVIX',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Universal media aggregator',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Text('v1.1.0',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: const Center(
                  child: Text('NGX',
                      style: TextStyle(
                          color: AppTheme.onAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neeraj {NGX}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text)),
                    SizedBox(height: 2),
                    Text('Creator & Developer',
                        style: TextStyle(
                            fontSize: 12.5, color: AppTheme.accentHi)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.35)),
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
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppTheme.accent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Text(
            'Designed and crafted with care by Neeraj {NGX} — a fast, cinematic home for your movies, shows and anime.',
            style: TextStyle(
                color: AppTheme.textDim, fontSize: 13.5, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(s,
          style: const TextStyle(
              color: AppTheme.textFaint,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4)),
    );
  }

  Widget _row({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                          fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.textDim)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
