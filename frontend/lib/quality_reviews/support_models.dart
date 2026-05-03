part of 'support.dart';

// ── 诊断数据提取辅助（私有）────────────────────────────────────────────────

Map<String, dynamic>? _qualityDiagnosticsMap(QualityReview row) {
  final params = row.modelParams;
  if (params == null) return null;
  final diagnostics = params['diagnostics'];
  if (diagnostics is! Map) return null;
  return Map<String, dynamic>.from(diagnostics);
}

Map<String, dynamic>? _feedbackMemoryMap(QualityReview row) {
  final diagnostics = _qualityDiagnosticsMap(row);
  if (diagnostics == null) return null;
  final feedback = diagnostics['feedbackMemory'];
  if (feedback is! Map) return null;
  return Map<String, dynamic>.from(feedback);
}

int _diagnosticInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toInt();
  return 0;
}

String? _diagnosticString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  return null;
}

bool _diagnosticBool(Map<String, dynamic> map, String key) => map[key] == true;

List<String> _diagnosticStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) return const <String>[];
  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
}

Map<String, int> _diagnosticStringIntMap(Map<String, dynamic> map, String key) {
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

String _describeAutoNegativeSource(String source) {
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

String _joinTopBucketCounts(Map<String, int> counts, {int maxItems = 3}) {
  if (counts.isEmpty) return '';
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(maxItems)
      .map((entry) => '${entry.key}${entry.value}次')
      .join(' / ');
}

String _joinBucketListWithCounts(
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

String _describeFeedbackFocusTag(String tag) {
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

String? _summarizeFeedbackFocusTags(Iterable<String> tags) {
  final values = LinkedHashSet<String>.from(
    tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
  ).toList(growable: false);
  if (values.isEmpty) return null;
  return values.map(_describeFeedbackFocusTag).join('/');
}

String _formatQualityScopeLabel(QualityReview row) {
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

String? _describeMemoryScopeRows({
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
