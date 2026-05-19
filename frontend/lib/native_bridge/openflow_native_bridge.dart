import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'generated/api.dart' as bridge_api;
import 'generated/frb_generated.dart';

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
    _initialized = true;
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

  @visibleForTesting
  void resetForTest() {
    OpenflowCoreBridgeApi.dispose();
    _initialized = false;
  }

  String get bridgeStatusMessage => shouldUseDesktopBridge
      ? (_initialized
            ? 'Desktop Rust bridge is initialized.'
            : 'Desktop Rust bridge bindings are generated and ready to initialize.')
      : 'Web runtime uses HTTP services instead of the desktop Rust bridge.';
}
