import '../rust_api.dart';

class NotificationProductScope {
  const NotificationProductScope({
    this.projectNumericId,
    this.projectUuid,
    this.workspaceId,
    this.scriptNumericId,
  });

  final int? projectNumericId;
  final String? projectUuid;
  final String? workspaceId;
  final int? scriptNumericId;

  bool get hasProjectScope =>
      projectNumericId != null ||
      (projectUuid != null && projectUuid!.isNotEmpty);
}

int? _parseScopeInt(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse(raw.toString().trim());
}

String? _parseScopeString(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

NotificationProductScope resolveNotificationProductScope(
  NotificationRecordV1 notification,
  Uri uri,
) {
  final query = uri.queryParameters;
  final payload = notification.payload;
  return NotificationProductScope(
    projectNumericId:
        _parseScopeInt(query['projectNumericId']) ??
        notification.projectNumericId ??
        _parseScopeInt(payload['projectNumericId']),
    projectUuid:
        _parseScopeString(query['projectUuid']) ??
        notification.projectId ??
        _parseScopeString(payload['projectId']),
    workspaceId:
        _parseScopeString(query['workspaceId']) ??
        notification.workspaceId ??
        _parseScopeString(payload['workspaceId']),
    scriptNumericId:
        _parseScopeInt(query['scriptNumericId']) ??
        _parseScopeInt(payload['scriptNumericId']),
  );
}
