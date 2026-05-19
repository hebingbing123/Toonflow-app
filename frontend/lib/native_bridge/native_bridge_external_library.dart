import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'native_bridge_external_library_stub.dart'
    if (dart.library.io) 'native_bridge_external_library_io.dart' as loader;

ExternalLibrary openNativeBridgeExternalLibrary(String path) {
  return loader.openNativeBridgeExternalLibrary(path);
}
