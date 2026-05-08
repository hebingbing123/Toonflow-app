import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('ValidateHarnessUserWasmResponse parses OpenAPI-shaped JSON', () {
    final r = ValidateHarnessUserWasmResponse.fromJson({
      'validated': true,
      'size_bytes': 38,
    });
    expect(r.validated, true);
    expect(r.sizeBytes, 38);
  });

  test('embedded probe matches backend build.rs module size', () {
    expect(kHarnessEmbeddedProbeWasm.length, 38);
  });
}
