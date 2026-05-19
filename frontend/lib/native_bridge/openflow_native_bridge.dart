import 'package:flutter/foundation.dart';

/// Stable Flutter-side entrypoint for the desktop Rust Core bridge.
///
/// Generated flutter_rust_bridge files should stay behind this facade so
/// product code does not import generated glue directly.
class OpenflowNativeBridge {
  const OpenflowNativeBridge._();

  static const OpenflowNativeBridge instance = OpenflowNativeBridge._();

  bool get shouldUseDesktopBridge => !kIsWeb;

  String get bridgeStatusMessage => shouldUseDesktopBridge
      ? 'Desktop Rust bridge scaffold is present. Generate bindings before first native call.'
      : 'Web runtime uses HTTP services instead of the desktop Rust bridge.';
}
