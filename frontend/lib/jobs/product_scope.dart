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
  return JobProductScope(
    projectNumericId: _payloadInt(payload['project_numeric_id']),
    projectUuid: _payloadString(payload['project_uuid']),
    workspaceId: _payloadString(payload['workspace_id']),
    scriptNumericId:
        _payloadInt(payload['script_numeric_id']) ??
        _payloadInt(payload['script_id']),
    scriptUuid: _payloadString(payload['script_uuid']),
  );
}
