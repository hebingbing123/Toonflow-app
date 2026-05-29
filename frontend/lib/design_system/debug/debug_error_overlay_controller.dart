import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'debug_overlay_widget.dart';
import 'debug_error_overlay_policy.dart';

/// Holds the latest debug error snapshot for the app-wide overlay host.
///
/// Active only in non-release builds ([report] is a no-op in release mode).
class DebugErrorOverlayController {
  DebugErrorOverlayController._();

  static final DebugErrorOverlayController instance =
      DebugErrorOverlayController._();

  final ValueNotifier<DebugErrorSnapshot?> snapshot =
      ValueNotifier<DebugErrorSnapshot?>(null);

  String? _pendingReportKey;
  bool _postFrameScheduled = false;
  DebugErrorSnapshot? _pendingSnapshot;
  int _updateGeneration = 0;

  void _scheduleSnapshotUpdate(DebugErrorSnapshot? next) {
    _pendingSnapshot = next;
    if (_postFrameScheduled) {
      return;
    }
    _postFrameScheduled = true;
    final generation = _updateGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _updateGeneration) {
        _postFrameScheduled = false;
        return;
      }
      _postFrameScheduled = false;
      if (kReleaseMode) {
        _pendingSnapshot = null;
        _pendingReportKey = null;
        return;
      }
      final value = _pendingSnapshot;
      _pendingSnapshot = null;
      _pendingReportKey = null;
      snapshot.value = value;
    });
  }

  /// Updates the overlay with [details]. No-op when [kReleaseMode] is true.
  ///
  /// Defers notification to the next frame so paint-time errors (e.g. flex
  /// overflow indicators) do not schedule rebuilds during layout/paint.
  void report(FlutterErrorDetails details) {
    if (kReleaseMode) {
      return;
    }
    if (isRenderFlexOverflowError(details)) {
      return;
    }
    final next = DebugErrorSnapshot.fromDetails(details);
    final key = '${next.exceptionType}:${next.message}';
    if (snapshot.value != null &&
        snapshot.value!.exceptionType == next.exceptionType &&
        snapshot.value!.message == next.message) {
      return;
    }
    if (_pendingReportKey == key) {
      return;
    }
    _pendingReportKey = key;
    _scheduleSnapshotUpdate(next);
  }

  /// Clears the on-screen overlay (e.g. after the user dismisses it).
  void clear() {
    _updateGeneration++;
    _pendingReportKey = null;
    _postFrameScheduled = false;
    _pendingSnapshot = null;
    snapshot.value = null;
  }

  @visibleForTesting
  void resetForTest() {
    _updateGeneration++;
    _pendingReportKey = null;
    _postFrameScheduled = false;
    _pendingSnapshot = null;
    snapshot.value = null;
  }
}
