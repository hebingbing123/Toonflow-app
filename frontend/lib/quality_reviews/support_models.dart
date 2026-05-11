import 'dart:collection';

import '../l10n/app_localizations.dart';
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

String describeAutoNegativeSource(
  String source, {
  AppLocalizations? l10n,
}) {
  switch (source) {
    case 'review+rejected_memory':
      return l10n?.qualityReviewsNegativeConstraintReviewAndBadCase ??
          '负向约束=评审+坏例记忆';
    case 'review':
      return l10n?.qualityReviewsNegativeConstraintRecentReviews ?? '负向约束=近期评审';
    case 'rejected_memory':
      return l10n?.qualityReviewsNegativeConstraintBadCaseMemory ?? '负向约束=坏例记忆';
    case 'pending_observation_note':
      return l10n?.qualityReviewsNegativeConstraintPendingBadCase ?? '负向约束=待观察坏例';
    case 'pending_rejected_observation':
      return l10n?.qualityReviewsNegativeConstraintPendingRejected ??
          '负向约束=待观察拒绝项';
    default:
      return l10n?.qualityReviewsNegativeConstraintGeneric(source) ??
          '负向约束=$source';
  }
}

String joinTopBucketCounts(
  Map<String, int> counts, {
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  if (counts.isEmpty) return '';
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(maxItems)
      .map(
        (entry) =>
            l10n?.qualityReviewsBucketCount(entry.key, entry.value) ??
            '${entry.key}${entry.value}次',
      )
      .join(' / ');
}

String joinBucketListWithCounts(
  List<String> buckets,
  Map<String, int> counts,
  {AppLocalizations? l10n}
) {
  if (buckets.isEmpty) return '';
  return buckets
      .map((bucket) {
        final count = counts[bucket];
        return count == null || count <= 1
            ? bucket
            : (l10n?.qualityReviewsBucketCount(bucket, count) ?? '$bucket$count次');
      })
      .join('/');
}

String describeFeedbackFocusTag(
  String tag, {
  AppLocalizations? l10n,
}) {
  switch (tag) {
    case 'delivery_realism':
      return l10n?.qualityReviewsFeedbackTagDeliveryRealism ?? '台词真实';
    case 'emotion_arc':
      return l10n?.qualityReviewsFeedbackTagEmotionArc ?? '情绪层次';
    case 'identity_continuity':
      return l10n?.qualityReviewsFeedbackTagIdentityContinuity ?? '人物一致';
    case 'lighting_realism':
      return l10n?.qualityReviewsFeedbackTagLightingRealism ?? '光影真实';
    default:
      return tag;
  }
}

String? summarizeFeedbackFocusTags(
  Iterable<String> tags, {
  AppLocalizations? l10n,
}) {
  final values = LinkedHashSet<String>.from(
    tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
  ).toList(growable: false);
  if (values.isEmpty) return null;
  return values
      .map((tag) => describeFeedbackFocusTag(tag, l10n: l10n))
      .join('/');
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
  AppLocalizations? l10n,
}) {
  final parts = <String>[
    if (projectScopeRows > 0)
      l10n?.qualityReviewsScopeProject(projectScopeRows) ?? '项目$projectScopeRows',
    if (scriptScopeRows > 0)
      l10n?.qualityReviewsScopeScript(scriptScopeRows) ?? '剧本$scriptScopeRows',
    if (roleScopeRows > 0)
      l10n?.qualityReviewsScopeRole(roleScopeRows) ?? '角色$roleScopeRows',
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

String qualityTokenEfficiencyFocusLabel(
  String focus, {
  AppLocalizations? l10n,
}) {
  switch (focus) {
    case 'selected_video_memory':
      return l10n?.qualityReviewsFocusSelectedVideoMemory ?? '镜头级精选记忆';
    case 'rejected_video_negative_memory':
      return l10n?.qualityReviewsFocusRejectedVideoNegativeMemory ?? '坏例记忆';
    case 'project_video_style_memory':
      return l10n?.qualityReviewsFocusProjectVideoStyleMemory ?? '项目级风格记忆';
    default:
      return l10n?.qualityReviewsFocusCurrentMemory ?? '当前记忆';
  }
}
