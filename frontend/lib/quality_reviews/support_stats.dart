import '../../rust_api.dart';
import 'support_models.dart';
import 'support_filters.dart';
import 'support_actions.dart';

String summarizeQualityTokenEfficiencyRows(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率统计';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final prompt = row.avgPromptChars.toStringAsFixed(0);
        final base = row.avgNonMemoryPromptChars.toStringAsFixed(0);
        final memory = row.avgMemoryStyleChars.toStringAsFixed(0);
        final share = row.avgMemorySharePercent.toStringAsFixed(1);
        final delivery = row.avgMemoryDeliveryChars.toStringAsFixed(0);
        final deliveryShare = row.avgDeliveryMemorySharePercent.toStringAsFixed(
          1,
        );
        final hitRate = row.deliveryPriorityHitRatePercent.toStringAsFixed(1);
        final parts = <String>[
          '${row.targetType}: prompt=$prompt, base=$base, memory=$memory ($share%, delivery=$delivery/$deliveryShare%, hit=$hitRate%)',
        ];
        final memoryAction = _qualityTokenEfficiencyMemoryActionSummary(row);
        if (memoryAction != null) {
          parts.add(memoryAction);
        }
        return parts.join(' · ');
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String? _qualityTokenEfficiencyMemoryActionSummary(
  QualityTokenEfficiencyRow row,
) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label = '动作=保留表演记忆';
      break;
    case 'reuse_negative_memory':
      label = '动作=复用坏例约束';
      break;
    case 'trim_generic_style_memory':
      label = '动作=压项目泛风格';
      break;
    case 'promote_selected_memory':
      label = '动作=晋升优质镜头';
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('焦点=$focus');
  }
  if (reason.isNotEmpty) {
    parts.add(reason);
  }
  return parts.join(' · ');
}

String summarizeQualityTokenEfficiencySamples(
  Iterable<QualityTokenEfficiencySampleRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率样本';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.createdAt.length >= 16
            ? row.createdAt.substring(5, 16).replaceFirst('T', ' ')
            : row.createdAt;
        final deliveryFlag = row.memoryDeliveryPriorityApplied
            ? 'delivery优先'
            : '常规';
        return '$date ${row.targetType}: prompt=${row.promptChars}, base=${row.nonMemoryPromptChars}, memory=${row.memoryStyleChars} (${row.memorySharePercent.toStringAsFixed(1)}%, $deliveryFlag)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量评审';
  }
  final autoCount = items.where((row) => row.source == 'auto').length;
  final visible = items
      .take(maxItems)
      .map((row) {
        final score = row.overallScore?.toString() ?? 'n/a';
        return '${row.targetType}:${row.source}:$score';
      })
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '评审 ${items.length} 条 · auto $autoCount 条 · $visible$suffix';
}

String summarizeQualityStatsRows(
  Iterable<QualityStatsRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量统计';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}% ($delivery, $nonDelivery)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityScopeInsightRows(
  Iterable<QualityScopeInsightRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 scope 榜单';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final parts = <String>[
          '${row.scopeLabel} ${row.totalReviews}条',
          'pass=${row.passRatePercent.toStringAsFixed(1)}%',
        ];
        if (row.badCaseCount > 0) {
          parts.add('坏例${row.badCaseCount}');
        }
        if (row.dialogueRiskCount > 0) {
          parts.add('情绪${row.dialogueRiskCount}');
        }
        if (row.visualRiskCount > 0) {
          parts.add('真实感${row.visualRiskCount}');
        }
        if (row.autoReviews > 0) {
          parts.add(
            'auto=${row.avgPromptChars.toStringAsFixed(0)}/${row.avgMemoryChars.toStringAsFixed(0)}/${row.avgMemoryDeliveryChars.toStringAsFixed(0)}',
          );
          if (row.memoryRemovedChars > 0 || row.memoryRemovedRows > 0) {
            parts.add(
              'slim ${row.memoryRemovedChars}c/${row.memoryRemovedRows}条',
            );
          }
        }
        if (row.feedbackSelectedMemoryPromotions > 0) {
          parts.add('晋升${row.feedbackSelectedMemoryPromotions}');
        }
        if (row.feedbackRejectedMemoryWrites > 0) {
          parts.add('坏例回写${row.feedbackRejectedMemoryWrites}');
        }
        if (row.feedbackSummaryMemoryWrites > 0) {
          parts.add('摘要回写${row.feedbackSummaryMemoryWrites}');
        }
        if (row.feedbackMemoryRemovedChars > 0 ||
            row.feedbackMemoryRemovedRows > 0) {
          parts.add(
            '回写slim ${row.feedbackMemoryRemovedChars}c/${row.feedbackMemoryRemovedRows}条',
          );
        }
        final focusSummary = summarizeFeedbackFocusTags(row.feedbackFocusTags);
        if (focusSummary != null) {
          parts.add('关注=$focusSummary');
        }
        final memoryAction = _qualityScopeInsightMemoryActionSummary(row);
        if (memoryAction != null) {
          parts.add(memoryAction);
        }
        return parts.join(' · ');
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return visible + suffix;
}

String? _qualityScopeInsightMemoryActionSummary(QualityScopeInsightRow row) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label = '动作=保留表演记忆';
      break;
    case 'reuse_negative_memory':
      label = '动作=复用坏例约束';
      break;
    case 'trim_generic_style_memory':
      label = '动作=压项目泛风格';
      break;
    case 'promote_selected_memory':
      label = '动作=晋升优质镜头';
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('焦点=$focus');
  }
  if (reason.isNotEmpty) {
    parts.add(reason);
  }
  return parts.join(' · ');
}

String summarizeStagePassRateRows(
  Iterable<StagePassRateRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有阶段通过率';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.reviewDate.length >= 10
            ? row.reviewDate.substring(0, 10)
            : row.reviewDate;
        final passRate = row.passRatePercent?.toStringAsFixed(1) ?? 'n/a';
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '$date ${row.targetType}:$passRate% ($delivery, $nonDelivery)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeStageGradeDistributionRows(
  Iterable<StageGradeDistributionRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有阶段等级分布';
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.stage}: A${row.gradeACount}/B${row.gradeBCount}/C${row.gradeCCount}/D${row.gradeDCount} · pass=${row.passRatePercent.toStringAsFixed(1)}%',
      )
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeDashboardStageGradeDistributionRows(
  Iterable<QualityDashboardStageGradeItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有阶段等级分布';
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.stage}: A${row.gradeACount}/B${row.gradeBCount}/C${row.gradeCCount}/D${row.gradeDCount} · pass=${row.passRatePercent.toStringAsFixed(1)}%',
      )
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeDashboardScopeInsightRows(
  Iterable<QualityDashboardScopeInsightItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 scope 榜单';
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.scopeLabel} ${row.totalReviews}条 · pass=${row.passRatePercent.toStringAsFixed(1)}% · 坏例${row.badCaseCount}',
      )
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeDashboardTokenEfficiencyRows(
  Iterable<QualityDashboardTokenEfficiencyItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率统计';
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.targetType}: prompt=${row.avgPromptChars.toStringAsFixed(0)}, memory=${row.avgMemoryStyleChars.toStringAsFixed(0)}, delivery=${row.avgMemoryDeliveryChars.toStringAsFixed(0)} · action=${row.memoryAction}',
      )
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeBadCaseStatItems(
  Iterable<BadCaseStatItem> items, {
  int maxItems = 4,
}) {
  final rows = items.toList(growable: false);
  if (rows.isEmpty) {
    return '当前没有坏例热点';
  }
  final visible = rows
      .take(maxItems)
      .map(
        (row) =>
            '${row.badCaseCategory ?? "未分类"} ${row.count}条 · pass=${row.passRatePercent.toStringAsFixed(1)}% · avg=${row.avgScore.toStringAsFixed(1)}',
      )
      .join(' | ');
  final suffix = rows.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String? buildQualityDashboardSummary({
  String? statsSummary,
  String? stagePassRateSummary,
  String? stageGradeSummary,
  String? scopeInsightsSummary,
  String? tokenEfficiencySummary,
  String? badCaseStatsSummary,
}) {
  final parts = <String>[
    if (statsSummary != null && statsSummary.isNotEmpty) '统计: $statsSummary',
    if (stagePassRateSummary != null && stagePassRateSummary.isNotEmpty)
      '阶段: $stagePassRateSummary',
    if (stageGradeSummary != null && stageGradeSummary.isNotEmpty)
      '等级: $stageGradeSummary',
    if (scopeInsightsSummary != null && scopeInsightsSummary.isNotEmpty)
      'Scope: $scopeInsightsSummary',
    if (tokenEfficiencySummary != null && tokenEfficiencySummary.isNotEmpty)
      'Token: $tokenEfficiencySummary',
    if (badCaseStatsSummary != null && badCaseStatsSummary.isNotEmpty)
      '坏例: $badCaseStatsSummary',
  ];
  if (parts.isEmpty) {
    return null;
  }
  return parts.join('\n');
}

String formatQualityReviewCoreDetails(QualityReview row) {
  return [
    row.id,
    row.targetType,
    row.source,
    if (row.projectId != null) 'project=${row.projectId}',
    if (row.scriptId != null) 'script=${row.scriptId}',
    if (row.memoryDeliveryPriorityApplied != null)
      'delivery_priority=${row.memoryDeliveryPriorityApplied}',
    if (row.targetId != null && row.targetId!.isNotEmpty)
      'target=${row.targetId}',
    if (row.overallScore != null) 'score=${row.overallScore}',
    if (row.passed != null) 'passed=${row.passed}',
    if (row.isBadCase) 'bad_case',
    if (row.badCaseCategory != null) 'category=${row.badCaseCategory}',
  ].join(' · ');
}

String formatQualityReviewDetails(QualityReview row) {
  final parts = [formatQualityReviewCoreDetails(row)];
  final diagnosticSummary = summarizeQualityReviewPromptDiagnostics(row);
  if (diagnosticSummary != null) {
    parts.add('诊断=$diagnosticSummary');
  }
  final writebackSummary = summarizeQualityReviewMemoryWriteback(row);
  if (writebackSummary != null) {
    parts.add('回写=$writebackSummary');
  }
  final repairSuggestions = buildQualityReviewRepairSuggestions(row);
  if (repairSuggestions.isNotEmpty) {
    parts.add('建议=${repairSuggestions.join(" / ")}');
  }
  return parts.join(' · ');
}
