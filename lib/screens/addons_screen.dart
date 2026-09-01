import 'package:flutter/material.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() => _error = null);
    try {
      final m = await _client.fetchManifest(url);
      await AddonManager.addManifestUrl(url);
      _controller.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added: ${m.name}')));
      }
    } catch (e) {
      setState(() => _error = 'Could not load manifest: $e');
    }
  }

  Future<void> _remove(String url) async {
    await AddonManager.removeManifestUrl(url);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add-ons')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: AppTheme.text),
            decoration: InputDecoration(
              labelText: 'Add-on manifest URL',
              hintText: 'https://.../manifest.json',
              errorText: _error,
              prefixIcon: const Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Validate & Add'),
          ),
          const SizedBox(height: 28),
          const Text('Installed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: 12),
          if (_urls.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Column(
                children: [
                  Icon(Icons.extension_off_rounded, size: 40, color: AppTheme.textDim),
                  SizedBox(height: 10),
                  Text('No add-ons yet', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Paste any Stremio-compatible manifest URL above.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                ],
              ),
            ),
          ..._urls.map((url) => FutureBuilder<AddonManifest>(
                future: _client.fetchManifest(url),
                builder: (context, snap) {
                  final name = snap.data?.name ?? (snap.hasError ? 'Unavailable' : 'Loading...');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.cardHi, shape: BoxShape.circle),
                          child: const Icon(Icons.extension_rounded, color: AppTheme.textDim),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text)),
                              const SizedBox(height: 2),
                              Text(url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textDim),
                          onPressed: () => _remove(url),
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
