import 'package:flutter/foundation.dart';

import 'native_bridge_external_library.dart';
import 'native_bridge_bootstrap_platform.dart';
import 'openflow_native_bridge.dart';

enum NativeBridgeStartupState { idle, skipped, ready, failed }

class NativeBridgeStartupSnapshot {
  const NativeBridgeStartupSnapshot({
    required this.state,
    required this.message,
    this.libraryPath,
    this.error,
  });

  final NativeBridgeStartupState state;
  final String message;
  final String? libraryPath;
  final Object? error;

  bool get isReady => state == NativeBridgeStartupState.ready;
}

class NativeBridgeBootstrap extends ChangeNotifier {
  NativeBridgeBootstrap({
    OpenflowNativeBridge? bridge,
    NativeBridgePlatformSupport? platformSupport,
    Future<void> Function()? initializeDefault,
    Future<void> Function(String path)? initializeFromPath,
    void Function(NativeBridgeStartupSnapshot snapshot)? logSnapshot,
  }) : _bridge = bridge ?? OpenflowNativeBridge.instance,
       _platformSupport =
           platformSupport ?? createNativeBridgePlatformSupport(),
       _initializeDefault = initializeDefault,
       _initializeFromPath = initializeFromPath,
       _logSnapshot = logSnapshot ?? _defaultLogSnapshot;

  static final NativeBridgeBootstrap instance = NativeBridgeBootstrap();

  final OpenflowNativeBridge _bridge;
  final NativeBridgePlatformSupport _platformSupport;
  final Future<void> Function()? _initializeDefault;
  final Future<void> Function(String path)? _initializeFromPath;
  final void Function(NativeBridgeStartupSnapshot snapshot) _logSnapshot;

  NativeBridgeStartupSnapshot _snapshot = const NativeBridgeStartupSnapshot(
    state: NativeBridgeStartupState.idle,
    message: 'Desktop bridge has not started yet.',
  );
  Future<NativeBridgeStartupSnapshot>? _startupFuture;

  NativeBridgeStartupSnapshot get snapshot => _snapshot;

  Future<NativeBridgeStartupSnapshot> ensureStarted() {
    return _startupFuture ??= _start();
  }

  Future<NativeBridgeStartupSnapshot> _start() async {
    if (!_bridge.shouldUseDesktopBridge) {
      return _updateSnapshot(
        const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.skipped,
          message: 'Web runtime skips the desktop Rust bridge.',
        ),
      );
    }

    try {
      await (_initializeDefault ?? _bridge.ensureInitialized)();
      return _updateSnapshot(
        const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.ready,
          message: 'Desktop Rust bridge is ready.',
        ),
      );
    } catch (defaultError) {
      if (!_platformSupport.supportsExplicitLibraryLoading) {
        return _updateSnapshot(
          NativeBridgeStartupSnapshot(
            state: NativeBridgeStartupState.failed,
            message: 'Desktop Rust bridge failed to initialize.',
            error: defaultError,
          ),
        );
      }

      final initializeFromPath =
          _initializeFromPath ?? _defaultInitializeFromPath;
      for (final candidate in _platformSupport.candidateLibraryPaths()) {
        try {
          await initializeFromPath(candidate);
          return _updateSnapshot(
            NativeBridgeStartupSnapshot(
              state: NativeBridgeStartupState.ready,
              message: 'Desktop Rust bridge loaded from $candidate.',
              libraryPath: candidate,
            ),
          );
        } catch (_) {
          continue;
        }
      }

      return _updateSnapshot(
        NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.failed,
          message: 'Desktop Rust bridge failed to initialize.',
          error: defaultError,
        ),
      );
    }
  }

  Future<void> _defaultInitializeFromPath(String path) {
    return _bridge.ensureInitialized(
      externalLibrary: openNativeBridgeExternalLibrary(path),
    );
  }

  NativeBridgeStartupSnapshot _updateSnapshot(
    NativeBridgeStartupSnapshot next,
  ) {
    _snapshot = next;
    _logSnapshot(next);
    notifyListeners();
    return next;
  }

  static void _defaultLogSnapshot(NativeBridgeStartupSnapshot snapshot) {
    final details = <String>[
      'state=${snapshot.state.name}',
      'message=${snapshot.message}',
      if (snapshot.libraryPath != null) 'library_path=${snapshot.libraryPath}',
      if (snapshot.error != null) 'error=${snapshot.error}',
    ];
    debugPrint('native_bridge_bootstrap: ${details.join(', ')}');
  }

  @visibleForTesting
  void resetForTest() {
    _startupFuture = null;
    _snapshot = const NativeBridgeStartupSnapshot(
      state: NativeBridgeStartupState.idle,
      message: 'Desktop bridge has not started yet.',
    );
    notifyListeners();
  }
}
