import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Post-frame scheduling helpers that avoid rebuild storms on web.
abstract final class StudioScheduler {
  static final Set<String> _onceUntilKeys = <String>{};
  static bool _oncePerFrameScheduled = false;
  static final List<VoidCallback> _oncePerFrameCallbacks =
      <VoidCallback>[];

  /// Runs [callback] at most once per frame (coalesced).
  static void scheduleOncePerFrame(VoidCallback callback) {
    _oncePerFrameCallbacks.add(callback);
    if (_oncePerFrameScheduled) {
      return;
    }
    _oncePerFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _oncePerFrameScheduled = false;
      final pending = List<VoidCallback>.from(_oncePerFrameCallbacks);
      _oncePerFrameCallbacks.clear();
      for (final fn in pending) {
        fn();
      }
    });
  }

  /// Runs [callback] at most once until it completes for [key].
  static void scheduleOnceUntil(String key, VoidCallback callback) {
    if (_onceUntilKeys.contains(key)) {
      return;
    }
    _onceUntilKeys.add(key);
    scheduleOncePerFrame(() {
      try {
        callback();
      } finally {
        _onceUntilKeys.remove(key);
      }
    });
  }

  @visibleForTesting
  static void resetForTest() {
    _onceUntilKeys.clear();
    _oncePerFrameScheduled = false;
    _oncePerFrameCallbacks.clear();
  }
}
