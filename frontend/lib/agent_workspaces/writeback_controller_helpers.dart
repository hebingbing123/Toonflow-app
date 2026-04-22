part of 'writeback_controller.dart';

class _ScriptPlanWritebackPayload {
  const _ScriptPlanWritebackPayload({
    required this.storySkeleton,
    required this.adaptationStrategy,
    required this.rawScript,
  });

  final String storySkeleton;
  final String adaptationStrategy;
  final Object? rawScript;
}

int? _parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) return null;
  return value;
}

List<Map<String, dynamic>> _normalizeScriptPlanRows(Object? scriptRaw) {
  final rows = <Map<String, dynamic>>[];
  if (scriptRaw is! List) {
    return rows;
  }
  for (final item in scriptRaw.whereType<Map<String, dynamic>>()) {
    final rawId = item['numeric_id'] ?? item['id'];
    int? scriptId;
    if (rawId is int) {
      scriptId = rawId;
    } else if (rawId is num) {
      scriptId = rawId.toInt();
    }
    final content = item['content'];
    if (scriptId != null && content is String) {
      rows.add(<String, dynamic>{'id': scriptId, 'content': content});
    }
  }
  return rows;
}

_ScriptPlanWritebackPayload? _extractScriptPlanWritebackPayload(
  Map<String, dynamic> candidate,
) {
  final payload = candidate['data'];
  if (payload is! Map<String, dynamic>) return null;
  return _ScriptPlanWritebackPayload(
    storySkeleton: (payload['storySkeleton'] as String?)?.trim() ?? '',
    adaptationStrategy: (payload['adaptationStrategy'] as String?)?.trim() ?? '',
    rawScript: payload['script'],
  );
}

