import 'package:flutter/foundation.dart';

import 'debug_overlay_widget.dart';

/// Holds the latest debug error snapshot for the app-wide overlay host.
///
/// Active only in non-release builds ([report] is a no-op in release mode).
class DebugErrorOverlayController {
  DebugErrorOverlayController._();

  static final DebugErrorOverlayController instance =
      DebugErrorOverlayController._();

  final ValueNotifier<DebugErrorSnapshot?> snapshot =
      ValueNotifier<DebugErrorSnapshot?>(null);

  /// Updates the overlay with [details]. No-op when [kReleaseMode] is true.
  void report(FlutterErrorDetails details) {
    if (kReleaseMode) {
      return;
    }
    snapshot.value = DebugErrorSnapshot.fromDetails(details);
  }

  /// Clears the on-screen overlay (e.g. after the user dismisses it).
  void clear() {
    snapshot.value = null;
  }

  @visibleForTesting
  void resetForTest() {
    snapshot.value = null;
  }
}
