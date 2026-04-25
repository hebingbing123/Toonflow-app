part of 'support.dart';

List<Map<String, dynamic>> _extractResultItems(Object? result) {
  if (result is! Map<String, dynamic>) {
    return const <Map<String, dynamic>>[];
  }
  final items = result['items'];
  if (items is! List) return const <Map<String, dynamic>>[];
  return items.whereType<Map<String, dynamic>>().toList(growable: false);
}

Map<String, dynamic>? _extractPlanDataMap(Map<String, dynamic>? result) {
  if (result == null) return null;
  final data = result['data'];
  if (data is Map<String, dynamic>) return data;
  return null;
}

Map<String, dynamic>? _buildNovelStageArgs(List<Map<String, dynamic>> items) {
  final ids = extractScriptWorkspaceNovelIds(<String, dynamic>{'items': items});
  if (ids.isEmpty) return null;
  return <String, dynamic>{'novelId': ids.first};
}

int _parseReviewCount(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

ScriptWorkspaceReview? parseScriptWorkspaceReview(
  Map<String, dynamic>? result,
) {
  if (result == null) return null;
  final raw = result['review'];
  if (raw is! Map<String, dynamic>) return null;
  final target = (raw['target'] as String?)?.trim() ?? '';
  final grade = (raw['grade'] as String?)?.trim().toUpperCase() ?? '';
  final nextAction = (raw['nextAction'] as String?)?.trim() ?? '';
  final summary = (raw['summary'] as String?)?.trim() ?? '';
  if (target.isEmpty || grade.isEmpty) {
    return null;
  }
  return ScriptWorkspaceReview(
    target: target,
    grade: grade,
    severeCount: _parseReviewCount(raw['severeCount']),
    mediumCount: _parseReviewCount(raw['mediumCount']),
    minorCount: _parseReviewCount(raw['minorCount']),
    nextAction: nextAction,
    summary: summary,
  );
}

Map<String, dynamic> _planSectionArgs(String key, {int maxChars = 1600}) {
  return <String, dynamic>{'key': key, 'maxChars': maxChars};
}

Map<String, dynamic> _novelTextWindowArgs(int novelId) {
  return <String, dynamic>{
    'novelId': novelId,
    'fields': const <String>['numeric_id', 'chapter', 'chapter_data'],
    'lineStart': 1,
    'lineEnd': 80,
    'maxChars': 1800,
  };
}

Map<String, dynamic> _novelEventWindowArgs(int novelId) {
  return <String, dynamic>{
    'novelId': novelId,
    'fields': const <String>['numeric_id', 'name', 'detail'],
    'limit': 8,
    'maxChars': 1200,
  };
}

Map<String, dynamic>? _scriptWindowArgs(int? scopeScriptId) {
  if (scopeScriptId == null) return null;
  return <String, dynamic>{
    'scriptId': scopeScriptId,
    'lineStart': 1,
    'lineEnd': 80,
    'maxChars': 2200,
  };
}

Map<String, dynamic>? _scriptTailWindowArgs(int? scopeScriptId) {
  if (scopeScriptId == null) return null;
  return <String, dynamic>{
    'scriptId': scopeScriptId,
    'lineStart': 61,
    'lineEnd': 120,
    'maxChars': 1600,
  };
}
