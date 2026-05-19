import 'native_bridge_bootstrap_platform.dart';

NativeBridgePlatformSupport createNativeBridgePlatformSupport() {
  return const _StubNativeBridgePlatformSupport();
}

class _StubNativeBridgePlatformSupport extends NativeBridgePlatformSupport {
  const _StubNativeBridgePlatformSupport();

  @override
  bool get supportsExplicitLibraryLoading => false;

  @override
  List<String> candidateLibraryPaths() => const <String>[];
}
