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

  test('PersistHarnessUserWasmResponse parses OpenAPI-shaped JSON', () {
    final r = PersistHarnessUserWasmResponse.fromJson({
      'id': 'b3b4cb26-62d4-4d5c-9486-74c4c5c62c94',
      'wasm_sha256_hex':
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'size_bytes': 38,
      'created_at': '2026-05-08T12:00:00.000Z',
    });
    expect(r.id, 'b3b4cb26-62d4-4d5c-9486-74c4c5c62c94');
    expect(r.sizeBytes, 38);
    expect(r.wasmSha256Hex.length, 64);
  });

  test('ListHarnessUserWasmResponse parses OpenAPI-shaped JSON', () {
    final r = ListHarnessUserWasmResponse.fromJson({
      'items': [
        {
          'id': 'b3b4cb26-62d4-4d5c-9486-74c4c5c62c94',
          'wasm_sha256_hex':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'size_bytes': 38,
          'created_at': '2026-05-08T12:00:00.000Z',
        },
      ],
    });
    expect(r.items.length, 1);
    expect(r.items.first.sizeBytes, 38);
  });

  test('RevokeHarnessUserWasmResponse parses OpenAPI-shaped JSON', () {
    final r = RevokeHarnessUserWasmResponse.fromJson({
      'id': 'b3b4cb26-62d4-4d5c-9486-74c4c5c62c94',
      'revoked_at': '2026-05-08T12:00:00.000Z',
    });
    expect(r.id, 'b3b4cb26-62d4-4d5c-9486-74c4c5c62c94');
    expect(r.revokedAt.toUtc().toIso8601String(), '2026-05-08T12:00:00.000Z');
  });
}
