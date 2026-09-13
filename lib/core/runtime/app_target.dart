import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Device-form detection and TV navigation policy.
///
/// One codebase ships to phones and TVs:
/// * the TV CI build forces TV mode with `--dart-define=MOVIX_TV=true`,
/// * at runtime [detect] additionally recognises Android TV/boxes via the
///   `android.software.leanback` feature, so the regular APK also adapts
///   when installed on a TV.
///
/// TV rules applied across the UI:
/// * oversized hit targets and 10-foot type,
/// * visible focus rings (a remote D-pad has no hover),
/// * no reliance on hover or scroll-for-reveal,
/// * lighter glass blur (TV GPUs are weaker than phones).
class AppTarget {
  AppTarget._();

  /// True when built with `--dart-define=MOVIX_TV=true`.
  static const bool forcedTv =
      bool.fromEnvironment('MOVIX_TV', defaultValue: false);

  static bool _isTv = forcedTv;

  static bool get isTv => _isTv;

  /// Call once before `runApp` (best-effort, never throws). A TV build is
  /// already forced TV, so detection only matters for the phone APK.
  static Future<void> detect() async {
    if (forcedTv) {
      _isTv = true;
      return;
    }
    try {
      if (kIsWeb || !Platform.isAndroid) return;
      final info = await DeviceInfoPlugin().androidInfo;
      final features = info.systemFeatures;
      final leanback = features.contains('android.software.leanback');
      final touch = features.contains('android.hardware.touchscreen');
      _isTv = leanback || !touch;
    } catch (_) {
      // Keep the default (false) if detection is unavailable.
    }
  }

  /// Spacing/type scale factor — TV gets roomier, 10-foot friendly UI.
  static double get scale => isTv ? 1.18 : 1.0;

  /// Blur sigma for glass surfaces; near-flat on TV for speed.
  static double get glassBlur => isTv ? 6 : 16;

  /// Focus ring styling shared by every focusable control.
  static const double focusRadius = 14;
  static const Color focusColor = Color(0xFF5CEFA0);
}
