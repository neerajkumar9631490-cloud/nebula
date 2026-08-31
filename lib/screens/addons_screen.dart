import 'package:flutter/material.dart';
import '../services/stremio/addon_manager.dart';
import '../services/stremio/addon_client.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: ${m.name}')),
        );
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
      appBar: AppBar(title: const Text('Stremio Add-ons')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Add-on manifest URL',
              hintText: 'https://v3-cinemeta.strem.io/manifest.json',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_link),
            label: const Text('Validate & Add'),
          ),
          const SizedBox(height: 24),
          const Text('Installed add-ons',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_urls.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No add-ons yet. Paste any Stremio-compatible manifest URL above.'),
            ),
          ..._urls.map((url) => FutureBuilder<AddonManifest>(
                future: _client.fetchManifest(url),
                builder: (context, snap) {
                  final name = snap.data?.name ?? url;
                  return ListTile(
                    leading: const Icon(Icons.extension),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _remove(url),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}
