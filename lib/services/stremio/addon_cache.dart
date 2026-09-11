import 'dart:async';
import 'package:http/http.dart' as http;
import '../../models/media_item.dart';
import '../../models/stream_result.dart';
import 'addon_client.dart';
import 'addon_manager.dart';

/// Shared fast lane for every Stremio network call.
///
/// Why the app felt slow: every screen (home, detail recs, meta,
/// search-hot, source picker, player) re-fetched every addon manifest
/// sequentially with 10-12s timeouts and zero caching — opening one
/// detail screen fired ~3 full manifest rounds.
///
/// This fixes it in one place:
/// * one keep-alive HTTP client (no per-request socket/TLS setup),
/// * manifest cache (15 min TTL) with in-flight dedup — concurrent
///   callers share a single network request,
/// * catalog-section cache (5 min, stale-while-revalidate),
/// * meta cache (10 min) and short-lived stream cache (90s) so the
///   source picker opens instantly on repeat visits,
/// * tighter timeouts so a dead addon fails fast instead of gating
///   the whole screen.
class AddonCache {
  static final AddonCache instance = AddonCache._internal();
  AddonCache._internal();

  static const manifestTtl = Duration(minutes: 15);
  static const sectionsTtl = Duration(minutes: 5);
  static const metaTtl = Duration(minutes: 10);
  static const streamsTtl = Duration(seconds: 90);

  /// Keep-alive client: reuses TCP/TLS connections across calls.
  final http.Client client = http.Client();

  final Map<String, _Entry<AddonManifest>> _manifests = {};
  final Map<String, Future<AddonManifest>> _manifestInflight = {};

  _Entry<List<CachedSection>>? _sections;

  final Map<String, _Entry<Map<String, dynamic>>> _metas = {};
  final Map<String, _Entry<List<StreamResult>>> _streams = {};

  void dispose() {
    try {
      client.close();
    } catch (_) {}
  }

  // ── Manifests ──────────────────────────────────────────

  Future<AddonManifest?> manifestOf(String manifestUrl) async {
    final now = DateTime.now();
    final hit = _manifests[manifestUrl];
    if (hit != null && now.difference(hit.at) < manifestTtl) {
      return hit.value;
    }
    final inflight = _manifestInflight[manifestUrl];
    if (inflight != null) {
      try {
        return await inflight;
      } catch (_) {
        return hit?.value;
      }
    }
    final future = AddonClient().fetchManifest(manifestUrl, client: client);
    _manifestInflight[manifestUrl] = future;
    try {
      final manifest = await future.timeout(const Duration(seconds: 8));
      _manifests[manifestUrl] = _Entry(manifest, now);
      return manifest;
    } catch (_) {
      // Dead addon: keep serving the stale manifest if we have one.
      return hit?.value;
    } finally {
      _manifestInflight.remove(manifestUrl);
    }
  }

  /// All reachable manifests, fetched in parallel (not one-by-one).
  /// Returns stale entries on total failure so screens still paint.
  Future<List<LoadedManifest>> manifests() async {
    final urls = await AddonManager.getManifestUrls();
    if (urls.isEmpty) return [];
    final results = await Future.wait(
      urls.map((url) async {
        final manifest = await manifestOf(url);
        if (manifest == null) return null;
        return LoadedManifest(
          baseUrl: AddonManager.baseUrlFromManifestUrl(url),
          manifest: manifest,
        );
      }),
    );
    return results.whereType<LoadedManifest>().toList();
  }

  // ── Catalog sections (raw, UI-agnostic) ─────────────────

  String _sectionsKey(List<LoadedManifest> ms, int perType) =>
      '${ms.map((m) => m.baseUrl).join(',')}#$perType';

  List<CachedSection>? freshSections(
      List<LoadedManifest> ms, int perType) {
    final e = _sections;
    if (e == null) return null;
    if (e.key != _sectionsKey(ms, perType)) return null;
    if (DateTime.now().difference(e.at) > sectionsTtl) return null;
    return e.value;
  }

  List<CachedSection>? staleSections() => _sections?.value;

  void storeSections(
      List<LoadedManifest> ms, int perType, List<CachedSection> sections) {
    _sections =
        _Entry(sections, DateTime.now(), key: _sectionsKey(ms, perType));
  }

  // ── Meta ────────────────────────────────────────────────

  Map<String, dynamic>? freshMeta(String key) {
    final e = _metas[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > metaTtl) return null;
    return e.value;
  }

  void storeMeta(String key, Map<String, dynamic> meta) {
    _metas[key] = _Entry(meta, DateTime.now());
    if (_metas.length > 200) {
      _metas.remove(_metas.keys.first);
    }
  }

  // ── Streams ─────────────────────────────────────────────

  List<StreamResult>? freshStreams(String key) {
    final e = _streams[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > streamsTtl) return null;
    return e.value;
  }

  void storeStreams(String key, List<StreamResult> streams) {
    _streams[key] = _Entry(List.of(streams), DateTime.now());
    if (_streams.length > 120) {
      _streams.remove(_streams.keys.first);
    }
  }

  void dropStreams(String key) => _streams.remove(key);

  static String streamKey(String itemId, String type, int season, int episode) =>
      '$itemId|$type|S$season:E$episode';
}

class _Entry<T> {
  final T value;
  final DateTime at;
  final String key;
  _Entry(this.value, this.at, {this.key = ''});
}

/// A manifest + its base URL, without pulling in catalog_service
/// (which would create an import cycle).
class LoadedManifest {
  final String baseUrl;
  final AddonManifest manifest;
  const LoadedManifest({required this.baseUrl, required this.manifest});
}

/// Raw cached catalog rows. [catalog] carries the filter/skip/pagination
/// metadata the See-All screen needs; items are the parsed models.
class CachedSection {
  final String title;
  final String subtitle;
  final String type;
  final List<MediaItem> items;
  final String baseUrl;
  final AddonCatalog catalog;
  final String addonName;

  const CachedSection({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.items,
    required this.baseUrl,
    required this.catalog,
    required this.addonName,
  });
}
