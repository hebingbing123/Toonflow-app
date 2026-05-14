import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'quality_reviews_l10n.dart';
import 'support_models.dart';
import 'support_filters.dart';
import 'support_actions.dart';

String summarizeQualityTokenEfficiencyRows(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoTokenEfficiencyStats;
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
          loc.qualityReviewsTokenEfficiencyStatLine(
            row.targetType,
            prompt,
            base,
            memory,
            share,
            delivery,
            deliveryShare,
            hitRate,
          ),
        ];
        final memoryAction = _qualityTokenEfficiencyMemoryActionSummary(
          row,
          l10n: loc,
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
  required AppLocalizations l10n,
}) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label = l10n.qualityReviewsActionKeepDeliveryMemory;
      break;
    case 'reuse_negative_memory':
      label = l10n.qualityReviewsActionReuseNegativeMemory;
      break;
    case 'trim_generic_style_memory':
      label = l10n.qualityReviewsActionTrimGenericStyle;
      break;
    case 'promote_selected_memory':
      label = l10n.qualityReviewsActionPromoteSelectedMemory;
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('${l10n.qualityReviewsFocusLabel}=$focus');
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoTokenEfficiencySamples;
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.createdAt.length >= 16
            ? row.createdAt.substring(5, 16).replaceFirst('T', ' ')
            : row.createdAt;
        final deliveryFlag = row.memoryDeliveryPriorityApplied
            ? loc.qualityReviewsDeliveryPriority
            : loc.qualityReviewsRegular;
        return loc.qualityReviewsTokenEfficiencySampleLine(
          date,
          row.targetType,
          '${row.promptChars}',
          '${row.nonMemoryPromptChars}',
          '${row.memoryStyleChars}',
          row.memorySharePercent.toStringAsFixed(1),
          deliveryFlag,
        );
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoReviews;
  }
  final autoCount = items.where((row) => row.source == 'auto').length;
  final visible = items
      .take(maxItems)
      .map((row) {
        final score =
            row.overallScore?.toString() ??
            loc.qualityReviewsAbbrevNotAvailable;
        return '${row.targetType}:${row.source}:$score';
      })
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return loc.qualityReviewsSummaryLine(
    items.length,
    autoCount,
    '$visible$suffix',
  );
}

String summarizeQualityStatsRows(
  Iterable<QualityStatsRow> rows, {
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoQualityStats;
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? loc.qualityReviewsStatDeliveryNa
            : loc.qualityReviewsStatDeliveryPassRate(
                row.deliveryPriorityPassRatePercent.toStringAsFixed(1),
              );
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? loc.qualityReviewsStatNonNa
            : loc.qualityReviewsStatNonPassRate(
                row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1),
              );
        return loc.qualityReviewsWorkbenchQualityStatRow(
          row.targetType,
          row.totalReviews,
          row.passRatePercent.toStringAsFixed(1),
          delivery,
          nonDelivery,
        );
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoScopeLeaderboard;
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final parts = <String>[
          '${row.scopeLabel} ${row.totalReviews}${loc.qualityReviewsItemUnit}',
          'pass=${row.passRatePercent.toStringAsFixed(1)}%',
        ];
        if (row.badCaseCount > 0) {
          parts.add('${loc.qualityReviewsFilterBadCase}${row.badCaseCount}');
        }
        if (row.dialogueRiskCount > 0) {
          parts.add('${loc.qualityReviewsEmotionRisk}${row.dialogueRiskCount}');
        }
        if (row.visualRiskCount > 0) {
          parts.add('${loc.qualityReviewsRealismRisk}${row.visualRiskCount}');
        }
        if (row.autoReviews > 0) {
          parts.add(
            'auto=${row.avgPromptChars.toStringAsFixed(0)}/${row.avgMemoryChars.toStringAsFixed(0)}/${row.avgMemoryDeliveryChars.toStringAsFixed(0)}',
          );
          if (row.memoryRemovedChars > 0 || row.memoryRemovedRows > 0) {
            parts.add(
              loc.qualityReviewsScopeInsightSlimChars(
                row.memoryRemovedChars,
                row.memoryRemovedRows,
                loc.qualityReviewsItemUnit,
              ),
            );
          }
        }
        if (row.feedbackSelectedMemoryPromotions > 0) {
          parts.add(
            '${loc.qualityReviewsPromotionsLabel}${row.feedbackSelectedMemoryPromotions}',
          );
        }
        if (row.feedbackRejectedMemoryWrites > 0) {
          parts.add(
            '${loc.qualityReviewsBadCaseWriteback}${row.feedbackRejectedMemoryWrites}',
          );
        }
        if (row.feedbackSummaryMemoryWrites > 0) {
          parts.add(
            '${loc.qualityReviewsSummaryWriteback}${row.feedbackSummaryMemoryWrites}',
          );
        }
        if (row.feedbackMemoryRemovedChars > 0 ||
            row.feedbackMemoryRemovedRows > 0) {
          parts.add(
            '${loc.qualityReviewsWritebackSlim} ${row.feedbackMemoryRemovedChars}c/${row.feedbackMemoryRemovedRows}${loc.qualityReviewsItemUnit}',
          );
        }
        final focusSummary = summarizeFeedbackFocusTags(
          row.feedbackFocusTags,
          l10n: loc,
        );
        if (focusSummary != null) {
          parts.add('${loc.qualityReviewsFocusWatch}=$focusSummary');
        }
        final memoryAction = _qualityScopeInsightMemoryActionSummary(
          row,
          l10n: loc,
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
  required AppLocalizations l10n,
}) {
  String? label;
  switch (row.memoryAction) {
    case 'keep_delivery_memory':
      label = l10n.qualityReviewsActionKeepDeliveryMemory;
      break;
    case 'reuse_negative_memory':
      label = l10n.qualityReviewsActionReuseNegativeMemory;
      break;
    case 'trim_generic_style_memory':
      label = l10n.qualityReviewsActionTrimGenericStyle;
      break;
    case 'promote_selected_memory':
      label = l10n.qualityReviewsActionPromoteSelectedMemory;
      break;
    default:
      label = null;
  }
  if (label == null) return null;
  final reason = row.memoryReason.trim();
  final focus = row.memoryFocus.trim();
  final parts = <String>[label];
  if (focus.isNotEmpty && focus != 'observe') {
    parts.add('${l10n.qualityReviewsFocusLabel}=$focus');
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoStagePassRate;
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.reviewDate.length >= 10
            ? row.reviewDate.substring(0, 10)
            : row.reviewDate;
        final passRate =
            row.passRatePercent?.toStringAsFixed(1) ??
            loc.qualityReviewsAbbrevNotAvailable;
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? loc.qualityReviewsStatDeliveryNa
            : loc.qualityReviewsStatDeliveryPassRate(
                row.deliveryPriorityPassRatePercent.toStringAsFixed(1),
              );
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? loc.qualityReviewsStatNonNa
            : loc.qualityReviewsStatNonPassRate(
                row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1),
              );
        return loc.qualityReviewsWorkbenchStagePassRateRow(
          date,
          row.targetType,
          passRate,
          delivery,
          nonDelivery,
        );
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoStageGradeDistribution;
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) => loc.qualityReviewsWorkbenchStageGradeRow(
          row.stage,
          row.gradeACount,
          row.gradeBCount,
          row.gradeCCount,
          row.gradeDCount,
          row.passRatePercent.toStringAsFixed(1),
        ),
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoStageGradeDistribution;
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) => loc.qualityReviewsWorkbenchStageGradeRow(
          row.stage,
          row.gradeACount,
          row.gradeBCount,
          row.gradeCCount,
          row.gradeDCount,
          row.passRatePercent.toStringAsFixed(1),
        ),
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoScopeLeaderboard;
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) =>
            '${row.scopeLabel} ${row.totalReviews}${loc.qualityReviewsItemUnit} · pass=${row.passRatePercent.toStringAsFixed(1)}% · ${loc.qualityReviewsFilterBadCase}${row.badCaseCount}',
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
  final loc = qualityReviewsResolveL10n(l10n);
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return loc.qualityReviewsNoTokenEfficiencyStats;
  }
  final visible = items
      .take(maxItems)
      .map(
        (row) => loc.qualityReviewsWorkbenchDashboardTokenRow(
          row.targetType,
          row.avgPromptChars.toStringAsFixed(0),
          row.avgMemoryStyleChars.toStringAsFixed(0),
          row.avgMemoryDeliveryChars.toStringAsFixed(0),
          row.memoryAction,
        ),
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
  final loc = qualityReviewsResolveL10n(l10n);
  final rows = items.toList(growable: false);
  if (rows.isEmpty) {
    return loc.qualityReviewsNoBadCaseHotspots;
  }
  final visible = rows
      .take(maxItems)
      .map(
        (row) =>
            '${row.badCaseCategory ?? loc.qualityReviewsUncategorized} ${row.count}${loc.qualityReviewsItemUnit} · pass=${row.passRatePercent.toStringAsFixed(1)}% · avg=${row.avgScore.toStringAsFixed(1)}',
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
  final loc = qualityReviewsResolveL10n(l10n);
  final parts = <String>[
    if (statsSummary != null && statsSummary.isNotEmpty)
      '${loc.qualityReviewsSummaryStatsPrefix}: $statsSummary',
    if (stagePassRateSummary != null && stagePassRateSummary.isNotEmpty)
      '${loc.qualityReviewsSummaryStagePrefix}: $stagePassRateSummary',
    if (stageGradeSummary != null && stageGradeSummary.isNotEmpty)
      '${loc.qualityReviewsSummaryGradePrefix}: $stageGradeSummary',
    if (scopeInsightsSummary != null && scopeInsightsSummary.isNotEmpty)
      loc.qualityReviewsSummaryScopeLine(scopeInsightsSummary),
    if (tokenEfficiencySummary != null && tokenEfficiencySummary.isNotEmpty)
      loc.qualityReviewsSummaryTokenLine(tokenEfficiencySummary),
    if (badCaseStatsSummary != null && badCaseStatsSummary.isNotEmpty)
      '${loc.qualityReviewsSummaryBadCasePrefix}: $badCaseStatsSummary',
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
  final loc = qualityReviewsResolveL10n(l10n);
  final parts = [formatQualityReviewCoreDetails(row)];
  final diagnosticSummary = summarizeQualityReviewPromptDiagnostics(row);
  if (diagnosticSummary != null) {
    parts.add('${loc.qualityReviewsDiagnosticLabel}=$diagnosticSummary');
  }
  final writebackSummary = summarizeQualityReviewMemoryWriteback(row);
  if (writebackSummary != null) {
    parts.add('${loc.qualityReviewsWritebackLabel}=$writebackSummary');
  }
  final repairSuggestions = buildQualityReviewRepairSuggestions(row, l10n: loc);
  if (repairSuggestions.isNotEmpty) {
    parts.add(
      '${loc.qualityReviewsSuggestionsLabel}=${repairSuggestions.join(' / ')}',
    );
  }
  return parts.join(' · ');
}
