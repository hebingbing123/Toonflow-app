import 'package:flutter/foundation.dart';

import 'native_bridge_external_library.dart';
import 'native_bridge_bootstrap_platform.dart';
import 'openflow_native_bridge.dart';

enum NativeBridgeStartupState { idle, skipped, ready, failed }

class NativeBridgeStartupSnapshot {
  const NativeBridgeStartupSnapshot({
    required this.state,
    this.message = '',
    this.libraryPath,
    this.error,
  });

  final NativeBridgeStartupState state;

  /// Optional diagnostic text for logs/tests only; UI uses [nativeBridgeStartupMessage].
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
        ),
      );
    }

    try {
      await (_initializeDefault ?? _bridge.ensureInitialized)();
      return _updateSnapshot(
        const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.ready,
        ),
      );
    } catch (defaultError) {
      if (!_platformSupport.supportsExplicitLibraryLoading) {
        return _updateSnapshot(
          NativeBridgeStartupSnapshot(
            state: NativeBridgeStartupState.failed,
            error: defaultError,
          ),
        );
      }

      final initializeFromPath =
          _initializeFromPath ?? _defaultInitializeFromPath;
      Object? lastCandidateError;
      for (final candidate in _platformSupport.candidateLibraryPaths()) {
        try {
          await initializeFromPath(candidate);
          return _updateSnapshot(
            NativeBridgeStartupSnapshot(
              state: NativeBridgeStartupState.ready,
              libraryPath: candidate,
            ),
          );
        } catch (error) {
          lastCandidateError = error;
          debugPrint(
            'native_bridge_bootstrap: candidate failed '
            'path=$candidate error=$error',
          );
        }
      }

      return _updateSnapshot(
        NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.failed,
          error: lastCandidateError ?? defaultError,
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
    );
    notifyListeners();
  }
}
