import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_optimistic_api_key.dart';
import 'package:openflow_app/rust_api/settings/api_keys.dart';

ApiKeyRecordV1 _key({required String id, ApiKeyStatusV1 status = ApiKeyStatusV1.active}) {
  return ApiKeyRecordV1(
    id: id,
    publicId: 'pub',
    displayName: 'Key',
    scope: ApiKeyScopeV1.readOnly,
    status: status,
    keyHint: 'hint',
    useCount: 0,
    isExpired: false,
    isUsable: status == ApiKeyStatusV1.active,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  test('studioApiKeyWithStatus toggles revoked state', () {
    final row = _key(id: 'a');
    final revoked = studioApiKeyWithStatus(row, ApiKeyStatusV1.revoked);
    expect(revoked.status, ApiKeyStatusV1.revoked);
    expect(revoked.isUsable, isFalse);
    expect(revoked.revokedAt, isNotNull);
  });

  test('studioApiKeyCountsAfterStatusChange updates active/revoked', () {
    final row = _key(id: 'a');
    final counts = studioApiKeyCountsAfterStatusChange(
      row: row,
      nextStatus: ApiKeyStatusV1.revoked,
      activeCount: 2,
      revokedCount: 1,
    );
    expect(counts.$1, 1);
    expect(counts.$2, 2);
  });

  test('studioRemoveApiKeyById removes matching row', () {
    final rows = <ApiKeyRecordV1>[_key(id: 'keep'), _key(id: 'drop')];
    final next = studioRemoveApiKeyById(rows, 'drop');
    expect(next.map((row) => row.id), ['keep']);
  });
}
