import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'generated/api.dart' as bridge_api;
import 'generated/frb_generated.dart';

/// Domain API version exposed by [bridge_api.bridgeHealth] on the Rust side.
///
/// Bump this and `bridge_api_version` in `rust_core/.../api.rs` together when
/// breaking FFI surface changes ship.
const int kExpectedBridgeApiVersion = 1;

/// Matches [media_image_doc::MAX_IMAGE_DIMENSION] on the Rust side.
const int kMaxImageDimension = 65536;

/// Stable Flutter-side entrypoint for the desktop Rust Core bridge.
///
/// Generated flutter_rust_bridge files should stay behind this facade so
/// product code does not import generated glue directly.
class OpenflowNativeBridge {
  OpenflowNativeBridge._();

  static final OpenflowNativeBridge instance = OpenflowNativeBridge._();

  bool _initialized = false;

  bool get shouldUseDesktopBridge => !kIsWeb;

  Future<void> ensureInitialized({
    ExternalLibrary? externalLibrary,
    bool forceSameCodegenVersion = true,
  }) async {
    if (!shouldUseDesktopBridge || _initialized) {
      return;
    }

    await OpenflowCoreBridgeApi.init(
      externalLibrary: externalLibrary,
      forceSameCodegenVersion: forceSameCodegenVersion,
    );
    await _assertCompatibleBridgeApi();
    _initialized = true;
  }

  void _assertValidImageDimensions(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError(
        'Image width and height must be positive (got ${width}x$height).',
      );
    }
    if (width > kMaxImageDimension || height > kMaxImageDimension) {
      throw ArgumentError(
        'Image width and height must be <= $kMaxImageDimension (got ${width}x$height).',
      );
    }
  }

  Future<void> _assertCompatibleBridgeApi() async {
    final health = await bridge_api.bridgeHealth();
    if (health.bridgeApiVersion != kExpectedBridgeApiVersion) {
      OpenflowCoreBridgeApi.dispose();
      throw StateError(
        'Incompatible Rust bridge API version: expected '
        '$kExpectedBridgeApiVersion, got ${health.bridgeApiVersion}. '
        'Rebuild libopenflow_core_bridge and regenerate flutter_rust_bridge bindings.',
      );
    }
  }

  Future<bridge_api.CoreBridgeHealth?> bridgeHealth() async {
    if (!shouldUseDesktopBridge) {
      return null;
    }

    await ensureInitialized();
    return bridge_api.bridgeHealth();
  }

  Future<bridge_api.TimelineSummary?> createEmptyTimelineSummary() async {
    if (!shouldUseDesktopBridge) {
      return null;
    }

    await ensureInitialized();
    final document = await bridge_api.newTimelineDocument();
    return bridge_api.summarizeTimelineDocument(document: document);
  }

  Future<bridge_api.ImageDocumentSummary?> createImageDocumentSummary({
    required int width,
    required int height,
  }) async {
    if (!shouldUseDesktopBridge) {
      return null;
    }

    await ensureInitialized();
    _assertValidImageDimensions(width, height);
    final document = await bridge_api.newImageDocument(
      width: width,
      height: height,
    );
    return bridge_api.summarizeImageDocument(document: document);
  }

  Future<bridge_api.WorkflowSummary?> createEmptyWorkflowSummary() async {
    if (!shouldUseDesktopBridge) {
      return null;
    }

    await ensureInitialized();
    final document = await bridge_api.newWorkflowDocument();
    return bridge_api.summarizeWorkflowDocument(document: document);
  }

  @visibleForTesting
  void initializeMock({required OpenflowCoreBridgeApiApi api}) {
    OpenflowCoreBridgeApi.initMock(api: api);
    _initialized = true;
  }

  /// Exposes [ensureInitialized]'s post-init contract check for unit tests.
  @visibleForTesting
  Future<void> verifyBridgeApiCompatibilityForTest() =>
      _assertCompatibleBridgeApi();

  @visibleForTesting
  void resetForTest() {
    try {
      OpenflowCoreBridgeApi.dispose();
    } on Object {
      // Compatibility checks dispose before throwing; ignore double teardown.
    }
    _initialized = false;
  }

  String get bridgeStatusMessage => shouldUseDesktopBridge
      ? (_initialized
            ? 'Desktop Rust bridge is initialized.'
            : 'Desktop Rust bridge bindings are generated and ready to initialize.')
      : 'Web runtime uses HTTP services instead of the desktop Rust bridge.';
}
