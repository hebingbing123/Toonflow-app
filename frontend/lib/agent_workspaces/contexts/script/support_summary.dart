part of 'support.dart';

List<String> summarizeScriptResultSnapshot(
  AppLocalizations l10n,
  String? toolName,
  Object? result,
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

  switch (normalizedTool) {
    case 'run_supervision_agent':
      final review = parseScriptWorkspaceReview(result);
      if (review == null) {
        return <String>[l10n.agentWorkspaceScriptSummaryReviewReturned];
      }
      final issueCount =
          review.severeCount + review.mediumCount + review.minorCount;
      final summary = review.summary.isEmpty ? '' : ' · ${review.summary}';
      return <String>[
        l10n.agentWorkspaceScriptSummaryReviewLine(
          review.target,
          review.grade,
          issueCount,
          summary,
        ),
      ];
    case 'get_planData':
      final data = _extractPlanDataMap(result);
      if (data is! Map<String, dynamic>) {
        return <String>[l10n.agentWorkspaceScriptSummaryPlanDataMissing];
      }
      final scriptRows = data['script'];
      final lines = <String>[];
      if ((data['storySkeleton'] as String?)?.trim().isNotEmpty == true) {
        lines.add(l10n.agentWorkspaceScriptSummaryStorySkeletonReady);
      }
      if ((data['adaptationStrategy'] as String?)?.trim().isNotEmpty == true) {
        lines.add(l10n.agentWorkspaceScriptSummaryAdaptationReady);
      }
      if (scriptRows is List) {
        lines.add(
          l10n.agentWorkspaceScriptSummaryPlanScripts(scriptRows.length),
        );
        if (scriptRows.isNotEmpty &&
            (data['storySkeleton'] as String?)?.trim().isNotEmpty == true &&
            (data['adaptationStrategy'] as String?)?.trim().isNotEmpty ==
                true) {
          lines.add(l10n.agentWorkspaceScriptSummaryRewriteReady);
        }
      }
      return lines.isEmpty
          ? <String>[l10n.agentWorkspaceScriptSummaryPlanDataReturned]
          : lines;
    case 'get_script_content':
      final content = (result['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) {
        return <String>[l10n.agentWorkspaceScriptSummaryScriptEmpty(0)];
      }
      return <String>[
        l10n.agentWorkspaceScriptSummaryScriptChars(content.length),
      ];
    case 'get_novel_text':
      final items = _extractResultItems(result);
      return items.isEmpty
          ? <String>[l10n.agentWorkspaceScriptSummaryNovelTextEmpty(0)]
          : <String>[
              l10n.agentWorkspaceScriptSummaryNovelTextCount(items.length),
            ];
    case 'get_novel_events':
      final items = _extractResultItems(result);
      return items.isEmpty
          ? <String>[l10n.agentWorkspaceScriptSummaryNovelEventsEmpty(0)]
          : <String>[
              l10n.agentWorkspaceScriptSummaryNovelEventsCount(items.length),
            ];
    default:
      return <String>[
        l10n.agentWorkspaceSummaryReturnedObjectKeys(result.keys.join(',')),
      ];
  }
}

List<int> extractScriptWorkspaceNovelIds(Object? result) {
  final items = _extractResultItems(result);
  final ids = <int>[];
  for (final row in items) {
    final rawId =
        row['numeric_id'] ?? row['numericId'] ?? row['numericId'] ?? row['id'];
    if (rawId is num && rawId > 0) {
      ids.add(rawId.toInt());
    }
  }
  return ids.toSet().toList(growable: false);
}

List<ScriptWorkspaceArgumentSuggestion>
buildScriptWorkspaceArgumentSuggestions({
  required AppLocalizations l10n,
  required String? selectedTool,
  required String? toolName,
  required Object? result,
}) {
  final normalizedSelectedTool = selectedTool?.trim() ?? '';
  if (normalizedSelectedTool != 'get_novel_text' &&
      normalizedSelectedTool != 'get_novel_events') {
    return const <ScriptWorkspaceArgumentSuggestion>[];
  }
  final ids = extractScriptWorkspaceNovelIds(result);
  if (ids.isEmpty) return const <ScriptWorkspaceArgumentSuggestion>[];

  final source = toolName?.trim();
  final suggestions = <ScriptWorkspaceArgumentSuggestion>[
    ScriptWorkspaceArgumentSuggestion(
      label: l10n.agentWorkspaceScriptArgFillFirstChapter,
      payload: _buildSuggestedNovelPayload(
        normalizedSelectedTool,
        novelId: ids.first,
      ),
    ),
  ];
  if (ids.length > 1) {
    suggestions.add(
      ScriptWorkspaceArgumentSuggestion(
        label: l10n.agentWorkspaceScriptArgFillFirstThreeChapters,
        payload: _buildSuggestedNovelPayload(
          normalizedSelectedTool,
          novelId: ids.take(3).first,
        ),
      ),
    );
  }
  if (source == 'get_novel_text' &&
      normalizedSelectedTool == 'get_novel_events') {
    suggestions.add(
      ScriptWorkspaceArgumentSuggestion(
        label: l10n.agentWorkspaceScriptArgCarryChapterToEvents,
        payload: _buildSuggestedNovelPayload(
          normalizedSelectedTool,
          novelId: ids.first,
        ),
      ),
    );
  }
  return suggestions;
}

Map<String, dynamic> _buildSuggestedNovelPayload(
  String selectedTool, {
  required int novelId,
}) {
  if (selectedTool == 'get_novel_events') {
    return _novelEventWindowArgs(novelId);
  }
  return _novelTextWindowArgs(novelId);
}
