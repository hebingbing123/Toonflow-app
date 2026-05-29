import 'package:flutter/material.dart';

import '../../native_bridge/openflow_native_bridge.dart';

/// Global render-lock for heavy local export / video synthesis (rebuild plan P0-3).
class StudioRenderLockController extends ChangeNotifier {
  StudioRenderLockController._();
  static final StudioRenderLockController instance = StudioRenderLockController._();

  int _depth = 0;
  String? _reason;

  bool get isLocked => _depth > 0;
  String? get reason => _reason;

  void acquire({String? reason}) {
    _depth++;
    _reason = reason ?? _reason;
    notifyListeners();
  }

  void release() {
    if (_depth <= 0) {
      return;
    }
    _depth--;
    if (_depth == 0) {
      _reason = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _depth = 0;
    _reason = null;
    super.dispose();
  }
}

/// Disables navigation and pointer events while [StudioRenderLockController] is locked.
class StudioRenderLockScope extends StatelessWidget {
  const StudioRenderLockScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioRenderLockController.instance,
      builder: (context, _) {
        final locked = StudioRenderLockController.instance.isLocked;
        return AbsorbPointer(
          absorbing: locked,
          child: Stack(
            children: <Widget>[
              child,
              if (locked)
                const ModalBarrier(
                  dismissible: false,
                  color: Color(0x66000000),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Runs [action] under a render lock; always releases in `finally`.
///
/// On desktop, also acquires the Rust FFI render lock when the bridge is available.
Future<T> studioRunWithRenderLock<T>(
  Future<T> Function() action, {
  String? reason,
}) async {
  final lock = StudioRenderLockController.instance;
  final bridge = OpenflowNativeBridge.instance;
  var nativeAcquired = false;

  if (bridge.shouldUseDesktopBridge) {
    try {
      nativeAcquired = await bridge.tryAcquireRenderLock();
    } on Object {
      nativeAcquired = false;
    }
    if (!nativeAcquired) {
      throw StateError('Native render lock is busy');
    }
  }

  lock.acquire(reason: reason);
  try {
    return await action();
  } finally {
    lock.release();
    if (nativeAcquired) {
      await bridge.releaseRenderLock();
    }
  }
}
