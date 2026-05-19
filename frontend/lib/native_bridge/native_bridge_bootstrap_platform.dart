import 'native_bridge_bootstrap_platform_stub.dart'
    if (dart.library.io) 'native_bridge_bootstrap_platform_io.dart'
    as platform;

abstract class NativeBridgePlatformSupport {
  const NativeBridgePlatformSupport();

  bool get supportsExplicitLibraryLoading;

  List<String> candidateLibraryPaths();
}

NativeBridgePlatformSupport createNativeBridgePlatformSupport() {
  return platform.createNativeBridgePlatformSupport();
}
