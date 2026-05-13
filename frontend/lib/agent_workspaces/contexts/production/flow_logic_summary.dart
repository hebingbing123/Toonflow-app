part of 'flow_logic.dart';

List<String> summarizeProductionResultSnapshot(
  AppLocalizations l10n,
  String? toolName,
  Object? result,
  String? suggestedFlowKey,
) {
  final normalizedTool = toolName?.trim() ?? '';
  if (result is! Map<String, dynamic>) {
    if (result is List) {
      return <String>[l10n.agentWorkspaceSummaryReturnedList(result.length)];
    }
    if (result is String && result.trim().isNotEmpty) {
      return <String>[
        l10n.agentWorkspaceSummaryReturnedText(result.trim().length),
      ];
    }
    return const <String>[];
  }

  final data = result['data'];
  if (normalizedTool == 'get_flowData' && data != null) {
    return summarizeProductionFlowValue(l10n, data, flowKey: suggestedFlowKey);
  }

  if (result['items'] is List) {
    final items = result['items'] as List<dynamic>;
    return <String>[l10n.agentWorkspaceProductionSummaryItems(items.length)];
  }

  final review = parseProductionSupervisionReview(result);
  if (review != null) {
    final focusedShots = summarizeProductionStoryboardFocusIds(
      review.storyboardIds,
    );
    final reviewScope = summarizeProductionStoryboardReviewScope(
      review.storyboardIds,
    );
    return <String>[
      l10n.agentWorkspaceProductionSummaryReviewHeadline(
        review.target,
        review.grade,
      ),
      l10n.agentWorkspaceProductionSummaryIssueBreakdown(
        review.severeCount,
        review.mediumCount,
        review.minorCount,
      ),
      if (review.assetIds.isNotEmpty)
        l10n.agentWorkspaceProductionSummaryFocusedAssets(
          review.assetIds.length,
        ),
      if (review.assetIds.isEmpty && review.assetTypes.isNotEmpty)
        l10n.agentWorkspaceProductionSummaryFocusedAssetScope(
          summarizeProductionAssetTypeScope(review.assetTypes),
        ),
      if (review.storyboardIds.isNotEmpty)
        l10n.agentWorkspaceProductionSummaryFocusedShots(
          review.storyboardIds.length,
        ),
      if (focusedShots.isNotEmpty) focusedShots,
      if ((review.nextAction == 'check_storyboard' ||
              review.nextAction == 'check_script' ||
              review.nextAction == 'generate_storyboard') &&
          reviewScope.isNotEmpty)
        reviewScope,
      if (review.summary.isNotEmpty) review.summary,
    ];
  }

  final text = result['result'];
  if (text is String && text.trim().isNotEmpty) {
    return <String>[l10n.agentWorkspaceSummaryReturnedText(text.trim().length)];
  }

  return <String>[
    l10n.agentWorkspaceSummaryReturnedObjectKeys(result.keys.join(',')),
  ];
}

List<String> summarizeProductionFlowValue(
  AppLocalizations l10n,
  Object? value, {
  String? flowKey,
}) {
  final normalizedKey = flowKey?.trim() ?? '';
  if (value == null) {
    return <String>[l10n.agentWorkspaceProductionSummaryFlowEmpty];
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return <String>[l10n.agentWorkspaceProductionSummaryFlowEmptyString];
    }
    final lines = '\n'.allMatches(trimmed).length + 1;
    if (normalizedKey == 'scriptPlan') {
      final sectionCount = countProductionScriptPlanSections(trimmed);
      return <String>[
        l10n.agentWorkspaceProductionSummaryTextChars(trimmed.length),
        l10n.agentWorkspaceProductionSummaryLineCount(lines),
        if (sectionCount > 0)
          l10n.agentWorkspaceProductionSummaryPlanSections(sectionCount),
        if (sectionCount > 0)
          l10n.agentWorkspaceProductionSummaryRewriteInherited,
      ];
    }
    if (normalizedKey == 'storyboardTable') {
      final rowCount = countProductionStoryboardTableRows(trimmed);
      final assetCount = extractProductionReferencedAssetIds(trimmed).length;
      return <String>[
        l10n.agentWorkspaceProductionSummaryTextChars(trimmed.length),
        l10n.agentWorkspaceProductionSummaryLineCount(lines),
        if (rowCount > 0)
          l10n.agentWorkspaceProductionSummaryStoryboardRows(rowCount),
        if (assetCount > 0)
          l10n.agentWorkspaceProductionSummaryLinkedAssets(assetCount),
      ];
    }
    return <String>[
      l10n.agentWorkspaceProductionSummaryTextChars(trimmed.length),
      l10n.agentWorkspaceProductionSummaryLineCount(lines),
    ];
  }
  if (value is List) {
    if (value.isEmpty) {
      return <String>[l10n.agentWorkspaceProductionSummaryFlowEmpty];
    }
    final first = value.first;
    if (first is Map<String, dynamic>) {
      final rows = value.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      final withUrl = rows.where((entry) {
        return productionFlowEntryHasMediaResult(entry);
      }).length;
      final withPrompt = rows.where((entry) {
        final raw = entry['prompt'];
        return raw is String && raw.trim().isNotEmpty;
      }).length;
      final states = rows
          .map((entry) {
            final raw = entry['state'];
            return raw is String ? raw.trim() : '';
          })
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .length;
      final lines = <String>[
        l10n.agentWorkspaceProductionSummaryListCount(value.length),
      ];
      if (withPrompt > 0) {
        lines.add(l10n.agentWorkspaceProductionSummaryPrompts(withPrompt));
      }
      if (withUrl > 0) {
        lines.add(l10n.agentWorkspaceProductionSummaryMediaUrls(withUrl));
      }
      if (normalizedKey == 'assets') {
        lines.add(summarizeProductionAssetReadiness(rows));
      }
      if (normalizedKey == 'storyboard') {
        final targetCount = rows
            .where(productionStoryboardEntryNeedsImageGeneration)
            .length;
        final missingIds = extractProductionStoryboardMissingImageIds(rows);
        final skippedCount = rows.length - targetCount;
        lines.add(summarizeProductionStoryboardReadiness(rows));
        if (targetCount > 0) {
          lines.add(
            l10n.agentWorkspaceProductionSummaryNeedImages(targetCount),
          );
        }
        if (missingIds.isNotEmpty) {
          lines.add(
            l10n.agentWorkspaceProductionSummaryMissingFrames(
              missingIds.length,
            ),
          );
        }
        if (skippedCount > 0) {
          lines.add(
            l10n.agentWorkspaceProductionSummaryTextOnlyCount(skippedCount),
          );
        }
      }
      if (states > 0) {
        lines.add(l10n.agentWorkspaceProductionSummaryStateTypes(states));
      }
      return lines;
    }
    return <String>[
      l10n.agentWorkspaceProductionSummaryListCount(value.length),
    ];
  }
  if (value is Map<String, dynamic>) {
    if (normalizedKey == 'storyboardTable') {
      final rowCount = countProductionStoryboardTableRows(value);
      final sampledRows = _readSummaryInt(value['rowCount']);
      final assetCount = extractProductionReferencedAssetIds(value).length;
      return <String>[
        summarizeProductionStoryboardTableCoverage(
          sampledRows: sampledRows > 0 ? sampledRows : rowCount,
          totalRows: rowCount > 0
              ? rowCount
              : _readSummaryInt(value['totalRows']),
        ),
        if (sampledRows > 0 && rowCount > 0)
          l10n.agentWorkspaceProductionSummaryStoryboardRows(sampledRows),
        if (sampledRows <= 0 && rowCount > 0)
          l10n.agentWorkspaceProductionSummaryStoryboardRows(rowCount),
        if (assetCount > 0)
          l10n.agentWorkspaceProductionSummaryLinkedAssets(assetCount),
      ];
    }
    final lines = <String>[
      l10n.agentWorkspaceProductionSummaryObjectKeyCount(value.keys.length),
    ];
    for (final entry in value.entries) {
      final child = entry.value;
      if (child is List) {
        lines.add(
          l10n.agentWorkspaceProductionSummaryObjectListEntry(
            entry.key,
            child.length,
          ),
        );
      } else if (child is String && child.trim().isNotEmpty) {
        lines.add(
          l10n.agentWorkspaceProductionSummaryObjectTextEntry(
            entry.key,
            child.trim().length,
          ),
        );
      }
      if (lines.length >= 4) {
        break;
      }
    }
    return lines;
  }
  return <String>[
    l10n.agentWorkspaceProductionSummaryReturnedType(
      value.runtimeType.toString(),
    ),
  ];
}

int _readSummaryInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
