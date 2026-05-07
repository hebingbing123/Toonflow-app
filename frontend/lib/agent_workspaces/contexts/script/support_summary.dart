part of 'support.dart';

List<String> summarizeScriptResultSnapshot(String? toolName, Object? result) {
  final normalizedTool = toolName?.trim() ?? '';
  if (result is! Map<String, dynamic>) {
    if (result is List) return <String>['返回列表 ${result.length} 项'];
    if (result is String && result.trim().isNotEmpty) {
      return <String>['返回文本 ${result.trim().length} 字'];
    }
    return const <String>[];
  }

  switch (normalizedTool) {
    case 'run_supervision_agent':
      final review = parseScriptWorkspaceReview(result);
      if (review == null) {
        return <String>['审核结果已返回'];
      }
      final issueCount =
          review.severeCount + review.mediumCount + review.minorCount;
      final summary = review.summary.isEmpty ? '' : ' · ${review.summary}';
      return <String>[
        '审核 ${review.target}：${review.grade} 级，问题 $issueCount 项$summary',
      ];
    case 'get_planData':
      final data = result['data'];
      if (data is! Map<String, dynamic>) {
        return <String>['planData 缺少 data'];
      }
      final scriptRows = data['script'];
      final lines = <String>[];
      if ((data['storySkeleton'] as String?)?.trim().isNotEmpty == true) {
        lines.add('故事骨架已就绪');
      }
      if ((data['adaptationStrategy'] as String?)?.trim().isNotEmpty == true) {
        lines.add('改编策略已就绪');
      }
      if (scriptRows is List) {
        lines.add('计划剧本 ${scriptRows.length} 条');
        if (scriptRows.isNotEmpty &&
            (data['storySkeleton'] as String?)?.trim().isNotEmpty == true &&
            (data['adaptationStrategy'] as String?)?.trim().isNotEmpty ==
                true) {
          lines.add('改写约束已可下游消费');
        }
      }
      return lines.isEmpty ? <String>['planData 已返回'] : lines;
    case 'get_script_content':
      final content = (result['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) return <String>['剧本正文为空'];
      return <String>['剧本正文 ${content.length} 字'];
    case 'get_novel_text':
      final items = _extractResultItems(result);
      return items.isEmpty
          ? <String>['章节材料为空']
          : <String>['章节材料 ${items.length} 条'];
    case 'get_novel_events':
      final items = _extractResultItems(result);
      return items.isEmpty
          ? <String>['小说事件为空']
          : <String>['小说事件 ${items.length} 条'];
    default:
      return <String>['返回对象 keys=${result.keys.join(",")}'];
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
      label: '填充首章',
      payload: _buildSuggestedNovelPayload(
        normalizedSelectedTool,
        novelId: ids.first,
      ),
    ),
  ];
  if (ids.length > 1) {
    suggestions.add(
      ScriptWorkspaceArgumentSuggestion(
        label: '填充前 3 章',
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
        label: '沿用章节到事件',
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
