import 'package:flutter/material.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class AddonsScreen extends StatefulWidget {
  const AddonsScreen({super.key});

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  final _controller = TextEditingController();
  final AddonClient _client = AddonClient();
  List<String> _urls = [];
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final urls = await AddonManager.getManifestUrls();
    if (mounted) setState(() => _urls = urls);
  }

  Future<void> _add() async {
    final url = _controller.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _error = 'Enter a valid manifest URL (https://.../manifest.json)');
      return;
    }
    setState(() {
      _error = null;
      _adding = true;
    });
    try {
      final m = await _client.fetchManifest(url);
      await AddonManager.addManifestUrl(url);
      _controller.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added: ${m.name}'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load manifest: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(String url) async {
    await AddonManager.removeManifestUrl(url);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add-ons'),
            Text('Extend your sources',
                style: TextStyle(fontSize: 12, color: AppTheme.textDim, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 110 + MediaQuery.of(context).padding.bottom),
        children: [
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.extension_rounded,
                          color: AppTheme.onAccent, size: 19),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Install add-on',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.text,
                                  fontSize: 15)),
                          Text('Paste any Stremio manifest URL',
                              style: TextStyle(
                                  color: AppTheme.textDim, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: AppTheme.text),
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'https://.../manifest.json',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Pressable(
                    onTap: _adding ? null : _add,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(AppTheme.rMd),
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: Center(
                        child: _adding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.onAccent),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_link_rounded,
                                      color: AppTheme.onAccent, size: 19),
                                  SizedBox(width: 8),
                                  Text('Validate & Add',
                                      style: TextStyle(
                                          color: AppTheme.onAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('Installed (${_urls.length})',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 12),
          if (_urls.isEmpty)
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.stroke, style: BorderStyle.solid),
              ),
              child: const Column(
                children: [
                  Icon(Icons.extension_off_rounded,
                      size: 42, color: AppTheme.textFaint),
                  SizedBox(height: 12),
                  Text('No add-ons yet',
                      style: TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  SizedBox(height: 6),
                  Text(
                      'Add-ons unlock movies, shows and live sources.\nPaste a manifest URL above to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textDim, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ..._urls.map((url) => FutureBuilder<AddonManifest>(
                future: _client.fetchManifest(url),
                builder: (context, snap) {
                  final name = snap.data?.name ??
                      (snap.hasError ? 'Unavailable' : 'Loading…');
                  final desc = snap.data?.description ?? url;
                  final ok = snap.hasData;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: ok
                                ? AppTheme.accent.withOpacity(0.15)
                                : Colors.white.withOpacity(0.07),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: ok
                                    ? AppTheme.accent.withOpacity(0.35)
                                    : AppTheme.stroke),
                          ),
                          child: Icon(Icons.extension_rounded,
                              color:
                                  ok ? AppTheme.accent : AppTheme.textDim,
                              size: 20),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.text,
                                            fontSize: 14.5)),
                                  ),
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ok
                                          ? AppTheme.accent.withOpacity(0.15)
                                          : AppTheme.danger.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(ok ? 'ACTIVE' : (snap.hasError ? 'ERROR' : '…'),
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: ok
                                                ? AppTheme.accent
                                                : AppTheme.textDim)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(desc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textDim)),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppTheme.danger, size: 20),
                            onPressed: () => _remove(url),
                            tooltip: 'Remove',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}
