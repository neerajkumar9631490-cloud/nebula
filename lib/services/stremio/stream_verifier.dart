import 'dart:async';
import 'package:http/http.dart' as http;
import '../../models/stream_result.dart';
import 'addon_cache.dart';

/// Automatic dead-source removal + HTTPS-first ordering.
///
/// Every HTTP/HLS URL is probed with a lightweight `Range: bytes=0-0`
/// request (no body is downloaded). Unreachable links are dropped so
/// they never appear in the picker; torrents — which can't be checked
/// without the engine — always rank last.
///
/// Fail-open design: if *no* probe gets a definitive answer (all
/// timeouts, e.g. offline or a network that blocks probing), the
/// original list is kept so the sheet never goes empty because of
/// the checker itself. Verdicts are cached for 5 minutes so repeat
/// opens stay instant.
class StreamVerifier {
  static final StreamVerifier instance = StreamVerifier._internal();
  StreamVerifier._internal();

  static const verdictTtl = Duration(minutes: 5);
  static const perUrlTimeout = Duration(seconds: 4);
  static const passBudget = Duration(seconds: 6);

  final Map<String, _Verdict> _verdicts = {};

  static const _probeHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Range': 'bytes=0-0',
  };

  /// Seeders advertised in a source label ('👤 42', '12 seeders',
  /// 'S: 8', '[5 seed]'). Returns -1 when the label says nothing.
  static int parseSeeders(String label) {
    const patterns = [
      '👤\\s*(\\d+)',
      '(\\d+)\\s*seeders?',
      '\\bS\\s*:\\s*(\\d+)',
      '\\[(\\d+)\\s*[Ss]eed',
    ];
    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false).firstMatch(label);
      if (m != null) return int.tryParse(m.group(1)!) ?? -1;
    }
    return -1;
  }

  /// Probe, filter and order. Returns HTTPS-first, torrents-last.
  Future<List<StreamResult>> verifyAndOrder(
      List<StreamResult> input) async {
    if (input.isEmpty) return input;
    final direct =
        input.where((r) => r.playable && r.url != null).toList();
    if (direct.isEmpty) return _order(input, const {});

    Map<String, bool> alive = {};
    var definitive = 0;
    try {
      final probes = await Future.wait(
        direct.map(_probe),
      ).timeout(passBudget, onTimeout: () => <_Probe>[]);
      for (final p in probes) {
        alive[p.url] = p.alive;
        if (p.definitive) definitive++;
      }
    } catch (_) {}

    // Fail-open: nothing answered definitively — keep everything and
    // just fix the ordering (HTTPS still first, torrents last).
    final Set<String> dead;
    if (definitive == 0) {
      dead = {};
    } else {
      dead = {
        for (final r in direct)
          if (alive[r.url] == false) r.url!,
      };
    }
    return _order(
      [for (final r in input) if (!dead.contains(r.url)) r],
      alive,
    );
  }

  /// Group rank: verified HTTPS (0) → other direct (1) → external (2)
  /// → torrent (3). Torrents sort by advertised seeders inside their
  /// group; everything else keeps discovery order (stable).
  List<StreamResult> _order(
      List<StreamResult> input, Map<String, bool> alive) {
    final index = <StreamResult, int>{};
    for (var i = 0; i < input.length; i++) {
      index[input[i]] = i;
    }
    int group(StreamResult r) {
      switch (r.kind) {
        case StreamKind.http:
        case StreamKind.hls:
          return alive[r.url] == true ? 0 : 1;
        case StreamKind.external:
          return 2;
        case StreamKind.torrent:
          return 3;
      }
    }

    final out = List<StreamResult>.of(input);
    out.sort((a, b) {
      final g = group(a).compareTo(group(b));
      if (g != 0) return g;
      if (a.kind == StreamKind.torrent &&
          b.kind == StreamKind.torrent) {
        final bySeeds =
            parseSeeders(b.label).compareTo(parseSeeders(a.label));
        if (bySeeds != 0) return bySeeds;
      }
      return (index[a] ?? 0).compareTo(index[b] ?? 0);
    });
    return out;
  }

  Future<_Probe> _probe(StreamResult r) async {
    final url = r.url!;
    final now = DateTime.now();
    final hit = _verdicts[url];
    if (hit != null && now.difference(hit.at) < verdictTtl) {
      return _Probe(url, hit.alive, hit.definitive);
    }
    _Probe result;
    try {
      final res = await AddonCache.instance.client
          .get(Uri.parse(url), headers: _probeHeaders)
          .timeout(perUrlTimeout);
      final code = res.statusCode;
      if (code == 429 || code == 408) {
        // Rate-limited / timeout status: indeterminate, keep the link.
        result = _Probe(url, true, false);
      } else if (code >= 200 && code < 400) {
        result = _Probe(url, true, true);
      } else {
        result = _Probe(url, false, true);
      }
    } catch (_) {
      // Timeout / DNS / socket: indeterminate, keep unless siblings
      // prove the network can answer (handled by the fail-open rule).
      result = _Probe(url, false, false);
    }
    _verdicts[url] = _Verdict(result.alive, result.definitive, now);
    if (_verdicts.length > 400) {
      _verdicts.remove(_verdicts.keys.first);
    }
    return result;
  }
}

class _Probe {
  final String url;
  final bool alive;
  final bool definitive;
  const _Probe(this.url, this.alive, this.definitive);
}

class _Verdict {
  final bool alive;
  final bool definitive;
  final DateTime at;
  const _Verdict(this.alive, this.definitive, this.at);
}
