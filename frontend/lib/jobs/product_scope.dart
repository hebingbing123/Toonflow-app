import '../rust_api.dart';

class JobProductScope {
  const JobProductScope({
    this.projectNumericId,
    this.projectUuid,
    this.workspaceId,
    this.scriptNumericId,
    this.scriptUuid,
  });

  final int? projectNumericId;
  final String? projectUuid;
  final String? workspaceId;
  final int? scriptNumericId;
  final String? scriptUuid;

  bool get hasProjectScope =>
      projectNumericId != null ||
      (projectUuid != null && projectUuid!.isNotEmpty);
}

int? _payloadInt(Object? raw) {
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

String? _payloadString(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

JobProductScope jobProductScopeFromRow(JobRow job) {
  final payload = job.payload;
  final result = job.result ?? const <String, dynamic>{};
  final projectNumericId =
      _payloadInt(payload['project_numeric_id']) ??
      _payloadInt(payload['projectNumericId']) ??
      _payloadInt(result['project_numeric_id']) ??
      _payloadInt(result['projectNumericId']) ??
      _payloadInt(payload['project_id']) ??
      _payloadInt(payload['projectId']);
  final projectUuid =
      _payloadString(payload['project_uuid']) ??
      _payloadString(payload['projectUuid']) ??
      _payloadString(result['project_uuid']) ??
      _payloadString(result['projectUuid']) ??
      _payloadString(result['projectId']) ??
      _payloadString(payload['projectId']);
  final workspaceId =
      _payloadString(payload['workspace_id']) ??
      _payloadString(payload['workspaceId']) ??
      _payloadString(result['workspace_id']) ??
      _payloadString(result['workspaceId']);
  final scriptNumericId =
      _payloadInt(payload['script_numeric_id']) ??
      _payloadInt(payload['scriptNumericId']) ??
      _payloadInt(result['script_numeric_id']) ??
      _payloadInt(result['scriptNumericId']) ??
      _payloadInt(payload['script_id']) ??
      _payloadInt(payload['scriptId']);
  final scriptUuid =
      _payloadString(payload['script_uuid']) ??
      _payloadString(payload['scriptUuid']) ??
      _payloadString(result['script_uuid']) ??
      _payloadString(result['scriptUuid']);
  return JobProductScope(
    projectNumericId: projectNumericId,
    projectUuid: projectUuid,
    workspaceId: workspaceId,
    scriptNumericId: scriptNumericId,
    scriptUuid: scriptUuid,
  );
}
