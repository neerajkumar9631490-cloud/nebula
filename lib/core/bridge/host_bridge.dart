import 'package:wakelock_plus/wakelock_plus.dart';

/// Device-capability seam between Core and the platform.
///
/// This is the "bridge" of the architecture: Core and UI talk to native
/// capabilities ONLY through this interface. On Flutter it is backed by
/// plugins ([PluginHostBridge]); a native Android shell would implement
/// the same contract over a MethodChannel in Kotlin without touching
/// Core or UI code.
///
/// NOTE: this repo's CI regenerates `android/` from `flutter create` on
/// every build, so hand-written Kotlin cannot live in-tree — which is
/// exactly why the capability lives behind this interface instead.
abstract class HostBridge {
  /// Keeps the screen awake during playback when [enabled].
  Future<void> setKeepAwake(bool enabled);
}

/// Plugin-backed [HostBridge] used by the app today.
class PluginHostBridge implements HostBridge {
  @override
  Future<void> setKeepAwake(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // A failed wakelock must never break playback.
    }
  }
}
