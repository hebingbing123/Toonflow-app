import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_filters.dart';
import 'support_actions.dart';

String summarizeQualityTokenEfficiencyRows(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoTokenEfficiencyStats ??
        'No token efficiency stats yet';
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
        final memoryAction = _qualityTokenEfficiencyMemoryActionSummary(
          row,
          l10n: l10n,
        );
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
  QualityTokenEfficiencyRow row, {
  AppLocalizations? l10n,
}) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label =
          l10n?.qualityReviewsActionKeepDeliveryMemory ??
          'action=keep delivery memory';
      break;
    case 'reuse_negative_memory':
      label =
          l10n?.qualityReviewsActionReuseNegativeMemory ??
          'action=reuse negative constraints';
      break;
    case 'trim_generic_style_memory':
      label =
          l10n?.qualityReviewsActionTrimGenericStyle ??
          'action=trim generic style memory';
      break;
    case 'promote_selected_memory':
      label =
          l10n?.qualityReviewsActionPromoteSelectedMemory ??
          'action=promote selected memory';
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('${l10n?.qualityReviewsFocusLabel ?? 'focus'}=$focus');
  }
  if (reason.isNotEmpty) {
    parts.add(reason);
  }
  return parts.join(' · ');
}

String summarizeQualityTokenEfficiencySamples(
  Iterable<QualityTokenEfficiencySampleRow> rows, {
  int maxItems = 4,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoTokenEfficiencySamples ??
        'No token efficiency samples yet';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.createdAt.length >= 16
            ? row.createdAt.substring(5, 16).replaceFirst('T', ' ')
            : row.createdAt;
        final deliveryFlag = row.memoryDeliveryPriorityApplied
            ? (l10n?.qualityReviewsDeliveryPriority ?? 'delivery-priority')
            : (l10n?.qualityReviewsRegular ?? 'regular');
        return '$date ${row.targetType}: prompt=${row.promptChars}, base=${row.nonMemoryPromptChars}, memory=${row.memoryStyleChars} (${row.memorySharePercent.toStringAsFixed(1)}%, $deliveryFlag)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoReviews ?? 'No quality reviews yet';
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
  return l10n?.qualityReviewsSummaryLine(
        items.length,
        autoCount,
        '$visible$suffix',
      ) ??
      'Reviews ${items.length} · auto $autoCount · $visible$suffix';
}

String summarizeQualityStatsRows(
  Iterable<QualityStatsRow> rows, {
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoQualityStats ?? 'No quality stats yet';
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
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoScopeLeaderboard ?? 'No scope leaderboard yet';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final parts = <String>[
          '${row.scopeLabel} ${row.totalReviews}${l10n?.qualityReviewsItemUnit ?? ' items'}',
          'pass=${row.passRatePercent.toStringAsFixed(1)}%',
        ];
        if (row.badCaseCount > 0) {
          parts.add(
            '${l10n?.qualityReviewsFilterBadCase ?? 'bad case'}${row.badCaseCount}',
          );
        }
        if (row.dialogueRiskCount > 0) {
          parts.add(
            '${l10n?.qualityReviewsEmotionRisk ?? 'emotion'}${row.dialogueRiskCount}',
          );
        }
        if (row.visualRiskCount > 0) {
          parts.add(
            '${l10n?.qualityReviewsRealismRisk ?? 'realism'}${row.visualRiskCount}',
          );
        }
        if (row.autoReviews > 0) {
          parts.add(
            'auto=${row.avgPromptChars.toStringAsFixed(0)}/${row.avgMemoryChars.toStringAsFixed(0)}/${row.avgMemoryDeliveryChars.toStringAsFixed(0)}',
          );
          if (row.memoryRemovedChars > 0 || row.memoryRemovedRows > 0) {
            parts.add(
              'slim ${row.memoryRemovedChars}c/${row.memoryRemovedRows}${l10n?.qualityReviewsItemUnit ?? ' items'}',
            );
          }
        }
        if (row.feedbackSelectedMemoryPromotions > 0) {
          parts.add(
            '${l10n?.qualityReviewsPromotionsLabel ?? 'promotions'}${row.feedbackSelectedMemoryPromotions}',
          );
        }
        if (row.feedbackRejectedMemoryWrites > 0) {
          parts.add(
            '${l10n?.qualityReviewsBadCaseWriteback ?? 'bad-case writeback'}${row.feedbackRejectedMemoryWrites}',
          );
        }
        if (row.feedbackSummaryMemoryWrites > 0) {
          parts.add(
            '${l10n?.qualityReviewsSummaryWriteback ?? 'summary writeback'}${row.feedbackSummaryMemoryWrites}',
          );
        }
        if (row.feedbackMemoryRemovedChars > 0 ||
            row.feedbackMemoryRemovedRows > 0) {
          parts.add(
            '${l10n?.qualityReviewsWritebackSlim ?? 'writeback slim'} ${row.feedbackMemoryRemovedChars}c/${row.feedbackMemoryRemovedRows}${l10n?.qualityReviewsItemUnit ?? ' items'}',
          );
        }
        final focusSummary = summarizeFeedbackFocusTags(
          row.feedbackFocusTags,
          l10n: l10n,
        );
        if (focusSummary != null) {
          parts.add(
            '${l10n?.qualityReviewsFocusWatch ?? 'watch'}=$focusSummary',
          );
        }
        final memoryAction = _qualityScopeInsightMemoryActionSummary(
          row,
          l10n: l10n,
        );
        if (memoryAction != null) {
          parts.add(memoryAction);
        }
        return parts.join(' · ');
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return visible + suffix;
}

String? _qualityScopeInsightMemoryActionSummary(
  QualityScopeInsightRow row, {
  AppLocalizations? l10n,
}) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label =
          l10n?.qualityReviewsActionKeepDeliveryMemory ??
          'action=keep delivery memory';
      break;
    case 'reuse_negative_memory':
      label =
          l10n?.qualityReviewsActionReuseNegativeMemory ??
          'action=reuse negative constraints';
      break;
    case 'trim_generic_style_memory':
      label =
          l10n?.qualityReviewsActionTrimGenericStyle ??
          'action=trim generic style memory';
      break;
    case 'promote_selected_memory':
      label =
          l10n?.qualityReviewsActionPromoteSelectedMemory ??
          'action=promote selected memory';
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('${l10n?.qualityReviewsFocusLabel ?? 'focus'}=$focus');
  }
  if (reason.isNotEmpty) {
    parts.add(reason);
  }
  return parts.join(' · ');
}

String summarizeStagePassRateRows(
  Iterable<StagePassRateRow> rows, {
  int maxItems = 4,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoStagePassRate ?? 'No stage pass rates yet';
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
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoStageGradeDistribution ??
        'No stage grade distribution yet';
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
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoStageGradeDistribution ??
        'No stage grade distribution yet';
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
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoScopeLeaderboard ?? 'No scope leaderboard yet';
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.scopeLabel} ${row.totalReviews}${l10n?.qualityReviewsItemUnit ?? ' items'} · pass=${row.passRatePercent.toStringAsFixed(1)}% · ${l10n?.qualityReviewsFilterBadCase ?? 'bad case'}${row.badCaseCount}',
      )
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeDashboardTokenEfficiencyRows(
  Iterable<QualityDashboardTokenEfficiencyItem> rows, {
  int maxItems = 4,
  AppLocalizations? l10n,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n?.qualityReviewsNoTokenEfficiencyStats ??
        'No token efficiency stats yet';
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
  AppLocalizations? l10n,
}) {
  final rows = items.toList(growable: false);
  if (rows.isEmpty) {
    return l10n?.qualityReviewsNoBadCaseHotspots ?? 'No bad-case hotspots yet';
  }
  final visible = rows
      .take(maxItems)
      .map(
        (row) =>
            '${row.badCaseCategory ?? (l10n?.qualityReviewsUncategorized ?? 'Uncategorized')} ${row.count}${l10n?.qualityReviewsItemUnit ?? ' items'} · pass=${row.passRatePercent.toStringAsFixed(1)}% · avg=${row.avgScore.toStringAsFixed(1)}',
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
  AppLocalizations? l10n,
}) {
  final parts = <String>[
    if (statsSummary != null && statsSummary.isNotEmpty)
      '${l10n?.qualityReviewsSummaryStatsPrefix ?? 'Stats'}: $statsSummary',
    if (stagePassRateSummary != null && stagePassRateSummary.isNotEmpty)
      '${l10n?.qualityReviewsSummaryStagePrefix ?? 'Stage'}: $stagePassRateSummary',
    if (stageGradeSummary != null && stageGradeSummary.isNotEmpty)
      '${l10n?.qualityReviewsSummaryGradePrefix ?? 'Grade'}: $stageGradeSummary',
    if (scopeInsightsSummary != null && scopeInsightsSummary.isNotEmpty)
      'Scope: $scopeInsightsSummary',
    if (tokenEfficiencySummary != null && tokenEfficiencySummary.isNotEmpty)
      'Token: $tokenEfficiencySummary',
    if (badCaseStatsSummary != null && badCaseStatsSummary.isNotEmpty)
      '${l10n?.qualityReviewsSummaryBadCasePrefix ?? 'Bad case'}: $badCaseStatsSummary',
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

String formatQualityReviewDetails(QualityReview row, {AppLocalizations? l10n}) {
  final parts = [formatQualityReviewCoreDetails(row)];
  final diagnosticSummary = summarizeQualityReviewPromptDiagnostics(row);
  if (diagnosticSummary != null) {
    parts.add(
      '${l10n?.qualityReviewsDiagnosticLabel ?? 'diagnostic'}=$diagnosticSummary',
    );
  }
  final writebackSummary = summarizeQualityReviewMemoryWriteback(row);
  if (writebackSummary != null) {
    parts.add(
      '${l10n?.qualityReviewsWritebackLabel ?? 'writeback'}=$writebackSummary',
    );
  }
  final repairSuggestions = buildQualityReviewRepairSuggestions(
    row,
    l10n: l10n,
  );
  if (repairSuggestions.isNotEmpty) {
    parts.add(
      '${l10n?.qualityReviewsSuggestionsLabel ?? 'suggestions'}=${repairSuggestions.join(' / ')}',
    );
  }
  return parts.join(' · ');
}
