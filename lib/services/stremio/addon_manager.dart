import 'package:shared_preferences/shared_preferences.dart';

class AddonManager {
  static const _key = 'stremio_addon_manifests';

  static Future<List<String>> getManifestUrls() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> addManifestUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final clean = url.trim();
    if (clean.isEmpty || list.contains(clean)) return;
    list.add(clean);
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeManifestUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(url);
    await prefs.setStringList(_key, list);
  }

  static String baseUrlFromManifestUrl(String manifestUrl) {
    var u = manifestUrl.trim();
    const suffix = '/manifest.json';
    if (u.endsWith(suffix)) {
      u = u.substring(0, u.length - suffix.length);
    } else if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
