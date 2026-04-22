part of 'run_controller.dart';

int? _parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) return null;
  return value;
}

Map<String, dynamic>? _parseJsonObject(
  String raw, {
  required String objectError,
  required String parseError,
  required WorkspaceRunErrorSink onErrorChanged,
}) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map<String, dynamic>) {
      onErrorChanged(objectError);
      return null;
    }
    return decoded;
  } catch (_) {
    onErrorChanged(parseError);
    return null;
  }
}

void _prepareWorkspaceRunState({
  required WorkspaceRunStateReset clearWsLog,
  required WorkspaceRunStateReset resetWorkspaceOutputs,
  required WorkspaceRunErrorSink onErrorChanged,
}) {
  clearWsLog();
  resetWorkspaceOutputs();
  onErrorChanged(null);
}

