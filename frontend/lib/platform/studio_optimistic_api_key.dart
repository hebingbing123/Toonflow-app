import '../../rust_api/settings/api_keys.dart';

ApiKeyRecordV1 studioApiKeyWithStatus(
  ApiKeyRecordV1 row,
  ApiKeyStatusV1 status,
) {
  final revokedAt = status == ApiKeyStatusV1.revoked
      ? DateTime.now().toUtc().toIso8601String()
      : null;
  return ApiKeyRecordV1(
    id: row.id,
    publicId: row.publicId,
    displayName: row.displayName,
    scope: row.scope,
    status: status,
    keyHint: row.keyHint,
    useCount: row.useCount,
    isExpired: row.isExpired,
    isUsable: status == ApiKeyStatusV1.active && !row.isExpired,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    expiresAt: row.expiresAt,
    revokedAt: revokedAt,
    rotatedAt: row.rotatedAt,
    lastUsedAt: row.lastUsedAt,
    lastUsedPath: row.lastUsedPath,
    lastUsedMethod: row.lastUsedMethod,
    lastUsedIp: row.lastUsedIp,
    lastUsedUserAgent: row.lastUsedUserAgent,
  );
}

List<ApiKeyRecordV1> studioReplaceApiKeyInList(
  List<ApiKeyRecordV1> items,
  ApiKeyRecordV1 updated,
) {
  final next = List<ApiKeyRecordV1>.from(items);
  final index = next.indexWhere((row) => row.id == updated.id);
  if (index >= 0) {
    next[index] = updated;
  }
  return next;
}

List<ApiKeyRecordV1> studioRemoveApiKeyById(
  List<ApiKeyRecordV1> items,
  String apiKeyId,
) {
  return items.where((row) => row.id != apiKeyId).toList(growable: false);
}

(int activeCount, int revokedCount) studioApiKeyCountsAfterStatusChange({
  required ApiKeyRecordV1 row,
  required ApiKeyStatusV1 nextStatus,
  required int activeCount,
  required int revokedCount,
}) {
  if (row.status == nextStatus) {
    return (activeCount, revokedCount);
  }
  var active = activeCount;
  var revoked = revokedCount;
  if (row.status == ApiKeyStatusV1.active) {
    active = (active - 1).clamp(0, active);
  } else {
    revoked = (revoked - 1).clamp(0, revoked);
  }
  if (nextStatus == ApiKeyStatusV1.active) {
    active += 1;
  } else {
    revoked += 1;
  }
  return (active, revoked);
}

(int activeCount, int revokedCount) studioApiKeyCountsAfterDelete({
  required ApiKeyRecordV1 row,
  required int activeCount,
  required int revokedCount,
}) {
  if (row.status == ApiKeyStatusV1.active) {
    return ((activeCount - 1).clamp(0, activeCount), revokedCount);
  }
  return (activeCount, (revokedCount - 1).clamp(0, revokedCount));
}
