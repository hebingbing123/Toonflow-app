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
        _parseScopeInt(query['project_id']) ??
        notification.projectNumericId ??
        _parseScopeInt(payload['projectNumericId']) ??
        _parseScopeInt(payload['project_numeric_id']) ??
        _parseScopeInt(payload['projectId']) ??
        _parseScopeInt(payload['project_id']),
    projectUuid:
        _parseScopeString(query['projectUuid']) ??
        _parseScopeString(query['project_uuid']) ??
        notification.projectId ??
        _parseScopeString(payload['projectUuid']) ??
        _parseScopeString(payload['project_uuid']) ??
        _parseScopeString(payload['projectId']) ??
        _parseScopeString(payload['project_id']),
    workspaceId:
        _parseScopeString(query['workspaceId']) ??
        _parseScopeString(query['workspace_id']) ??
        notification.workspaceId ??
        _parseScopeString(payload['workspaceId']) ??
        _parseScopeString(payload['workspace_id']),
    scriptNumericId:
        _parseScopeInt(query['scriptNumericId']) ??
        _parseScopeInt(query['script_numeric_id']) ??
        _parseScopeInt(payload['scriptNumericId']) ??
        _parseScopeInt(payload['script_numeric_id']),
  );
}
