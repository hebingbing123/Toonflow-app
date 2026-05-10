import 'dart:collection';

import '../../rust_api.dart';

// ── 通用辅助函数 ────────────────────────────────────────────────

int qualityScorePercent(int? score, {int fallback = 10}) {
  final normalized = (score ?? fallback).clamp(0, 10);
  return normalized * 10;
}

// ── 诊断数据提取辅助 ────────────────────────────────────────────────

Map<String, dynamic>? qualityDiagnosticsMap(QualityReview row) {
  final params = row.modelParams;
  if (params == null) return null;
  final diagnostics = params['diagnostics'];
  if (diagnostics is! Map) return null;
  return Map<String, dynamic>.from(diagnostics);
}

Map<String, dynamic>? feedbackMemoryMap(QualityReview row) {
  final diagnostics = qualityDiagnosticsMap(row);
  if (diagnostics == null) return null;
  final feedback = diagnostics['feedbackMemory'];
  if (feedback is! Map) return null;
  return Map<String, dynamic>.from(feedback);
}

int diagnosticInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toInt();
  return 0;
}

String? diagnosticString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  return null;
}

bool diagnosticBool(Map<String, dynamic> map, String key) => map[key] == true;

List<String> diagnosticStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) return const <String>[];
  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
}

Map<String, int> diagnosticStringIntMap(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map) return const <String, int>{};
  final result = <String, int>{};
  for (final entry in value.entries) {
    final bucket = entry.key;
    final count = entry.value;
    if (bucket is String && bucket.isNotEmpty && count is num && count > 0) {
      result[bucket] = count.toInt();
    }
  }
  return result;
}

String describeAutoNegativeSource(String source) {
  switch (source) {
    case 'review+rejected_memory':
      return '负向约束=评审+坏例记忆';
    case 'review':
      return '负向约束=近期评审';
    case 'rejected_memory':
      return '负向约束=坏例记忆';
    case 'pending_observation_note':
      return '负向约束=待观察坏例';
    case 'pending_rejected_observation':
      return '负向约束=待观察拒绝项';
    default:
      return '负向约束=$source';
  }
}

String joinTopBucketCounts(Map<String, int> counts, {int maxItems = 3}) {
  if (counts.isEmpty) return '';
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(maxItems)
      .map((entry) => '${entry.key}${entry.value}次')
      .join(' / ');
}

String joinBucketListWithCounts(
  List<String> buckets,
  Map<String, int> counts,
) {
  if (buckets.isEmpty) return '';
  return buckets
      .map((bucket) {
        final count = counts[bucket];
        return count == null || count <= 1 ? bucket : '$bucket$count次';
      })
      .join('/');
}

String describeFeedbackFocusTag(String tag) {
  switch (tag) {
    case 'delivery_realism':
      return '台词真实';
    case 'emotion_arc':
      return '情绪层次';
    case 'identity_continuity':
      return '人物一致';
    case 'lighting_realism':
      return '光影真实';
    default:
      return tag;
  }
}

String? summarizeFeedbackFocusTags(Iterable<String> tags) {
  final values = LinkedHashSet<String>.from(
    tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
  ).toList(growable: false);
  if (values.isEmpty) return null;
  return values.map(describeFeedbackFocusTag).join('/');
}

String formatQualityScopeLabel(QualityReview row) {
  if (row.projectId != null && row.scriptId != null) {
    return 'P${row.projectId}/S${row.scriptId}';
  }
  if (row.projectId != null) {
    return 'P${row.projectId}';
  }
  if (row.targetId != null && row.targetId!.isNotEmpty) {
    return row.targetId!;
  }
  return row.targetType;
}

String? describeMemoryScopeRows({
  required int projectScopeRows,
  required int scriptScopeRows,
  required int roleScopeRows,
}) {
  final parts = <String>[
    if (projectScopeRows > 0) '项目$projectScopeRows',
    if (scriptScopeRows > 0) '剧本$scriptScopeRows',
    if (roleScopeRows > 0) '角色$roleScopeRows',
  ];
  if (parts.isEmpty) return null;
  return parts.join('/');
}

int qualityTokenEfficiencyActionPriority(String action) {
  switch (action) {
    case 'keep_delivery_memory':
      return 4;
    case 'reuse_negative_memory':
      return 3;
    case 'trim_generic_style_memory':
      return 2;
    case 'promote_selected_memory':
      return 1;
    default:
      return 0;
  }
}

String qualityTokenEfficiencyFocusLabel(String focus) {
  switch (focus) {
    case 'selected_video_memory':
      return '镜头级精选记忆';
    case 'rejected_video_negative_memory':
      return '坏例记忆';
    case 'project_video_style_memory':
      return '项目级风格记忆';
    default:
      return '当前记忆';
  }
}
