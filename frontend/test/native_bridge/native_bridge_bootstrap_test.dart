import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap_platform.dart';

void main() {
  test(
    'bootstrap reports ready when default initialization succeeds',
    () async {
      final loggedSnapshots = <NativeBridgeStartupSnapshot>[];
      final bootstrap = NativeBridgeBootstrap(initializeDefault: () async {});
      final loggingBootstrap = NativeBridgeBootstrap(
        initializeDefault: () async {},
        logSnapshot: loggedSnapshots.add,
      );

      final snapshot = await bootstrap.ensureStarted();
      final loggedSnapshot = await loggingBootstrap.ensureStarted();

      expect(snapshot.state, NativeBridgeStartupState.ready);
      expect(snapshot.libraryPath, isNull);
      expect(loggedSnapshot.state, NativeBridgeStartupState.ready);
      expect(loggedSnapshots.single.message, 'Desktop Rust bridge is ready.');
    },
  );

  test('bootstrap falls back to explicit library candidates', () async {
    final attemptedPaths = <String>[];
    final bootstrap = NativeBridgeBootstrap(
      platformSupport: _TestPlatformSupport(
        supportsExplicitLibraryLoading: true,
        candidatePaths: const [
          'missing/libopenflow_core_bridge.dylib',
          'debug/libopenflow_core_bridge.dylib',
        ],
      ),
      initializeDefault: () async => throw StateError('default failed'),
      initializeFromPath: (path) async {
        attemptedPaths.add(path);
        if (!path.startsWith('debug/')) {
          throw StateError('not here');
        }
      },
    );

    final snapshot = await bootstrap.ensureStarted();

    expect(snapshot.state, NativeBridgeStartupState.ready);
    expect(attemptedPaths, const [
      'missing/libopenflow_core_bridge.dylib',
      'debug/libopenflow_core_bridge.dylib',
    ]);
    expect(snapshot.libraryPath, 'debug/libopenflow_core_bridge.dylib');
  });

  test(
    'bootstrap reports failed state when all startup attempts fail',
    () async {
      final bootstrap = NativeBridgeBootstrap(
        platformSupport: _TestPlatformSupport(
          supportsExplicitLibraryLoading: true,
          candidatePaths: const ['debug/libopenflow_core_bridge.dylib'],
        ),
        initializeDefault: () async => throw StateError('default failed'),
        initializeFromPath: (_) async => throw StateError('fallback failed'),
      );

      final snapshot = await bootstrap.ensureStarted();

      expect(snapshot.state, NativeBridgeStartupState.failed);
      expect(snapshot.error, isA<StateError>());
    },
  );

  test('bootstrap only initializes once', () async {
    var initializeCount = 0;
    final bootstrap = NativeBridgeBootstrap(
      initializeDefault: () async {
        initializeCount += 1;
      },
    );

    final first = await bootstrap.ensureStarted();
    final second = await bootstrap.ensureStarted();

    expect(first.state, NativeBridgeStartupState.ready);
    expect(second.state, NativeBridgeStartupState.ready);
    expect(initializeCount, 1);
  });
}

class _TestPlatformSupport extends NativeBridgePlatformSupport {
  const _TestPlatformSupport({
    required this.supportsExplicitLibraryLoading,
    required this.candidatePaths,
  });

  @override
  final bool supportsExplicitLibraryLoading;

  final List<String> candidatePaths;

  @override
  List<String> candidateLibraryPaths() => candidatePaths;
}
