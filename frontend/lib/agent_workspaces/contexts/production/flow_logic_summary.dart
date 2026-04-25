part of 'flow_logic.dart';

List<String> summarizeProductionResultSnapshot(
  String? toolName,
  Object? result,
  String? suggestedFlowKey,
) {
  final normalizedTool = toolName?.trim() ?? '';
  if (result is! Map<String, dynamic>) {
    if (result is List) {
      return <String>['返回列表 ${result.length} 项'];
    }
    if (result is String && result.trim().isNotEmpty) {
      return <String>['返回文本 ${result.trim().length} 字'];
    }
    return const <String>[];
  }

  final data = result['data'];
  if (normalizedTool == 'get_flowData' && data != null) {
    return summarizeProductionFlowValue(data, flowKey: suggestedFlowKey);
  }

  if (result['items'] is List) {
    final items = result['items'] as List<dynamic>;
    return <String>['返回 items ${items.length} 项'];
  }

  final review = parseProductionSupervisionReview(result);
  if (review != null) {
    return <String>[
      '审核 ${review.target} → ${review.grade}',
      '严重 ${review.severeCount} / 中等 ${review.mediumCount} / 轻微 ${review.minorCount}',
      if (review.summary.isNotEmpty) review.summary,
    ];
  }

  final text = result['result'];
  if (text is String && text.trim().isNotEmpty) {
    return <String>['返回文本 ${text.trim().length} 字'];
  }

  return <String>['返回对象 keys=${result.keys.join(',')}'];
}

List<String> summarizeProductionFlowValue(Object? value, {String? flowKey}) {
  final normalizedKey = flowKey?.trim() ?? '';
  if (value == null) {
    return const <String>['当前 flow 为空'];
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>['当前 flow 为空字符串'];
    }
    final lines = '\n'.allMatches(trimmed).length + 1;
    if (normalizedKey == 'scriptPlan') {
      final sectionCount = countProductionScriptPlanSections(trimmed);
      return <String>[
        '文本 ${trimmed.length} 字',
        '$lines 行',
        if (sectionCount > 0) '规划维度 $sectionCount/6',
      ];
    }
    if (normalizedKey == 'storyboardTable') {
      final rowCount = countProductionStoryboardTableRows(trimmed);
      final assetCount = extractProductionReferencedAssetIds(trimmed).length;
      return <String>[
        '文本 ${trimmed.length} 字',
        '$lines 行',
        if (rowCount > 0) '分镜表 $rowCount 行',
        if (assetCount > 0) '关联资产 $assetCount 项',
      ];
    }
    return <String>['文本 ${trimmed.length} 字', '$lines 行'];
  }
  if (value is List) {
    if (value.isEmpty) {
      return const <String>['当前列表为空'];
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
      final lines = <String>['列表 ${value.length} 项'];
      if (withPrompt > 0) lines.add('含提示词 $withPrompt 项');
      if (withUrl > 0) lines.add('含媒体地址 $withUrl 项');
      if (normalizedKey == 'storyboard') {
        final targetCount = rows
            .where(productionStoryboardEntryNeedsImageGeneration)
            .length;
        final missingIds = extractProductionStoryboardMissingImageIds(rows);
        final skippedCount = rows.length - targetCount;
        if (targetCount > 0) lines.add('需出图 $targetCount 项');
        if (missingIds.isNotEmpty) lines.add('缺帧 ${missingIds.length} 项');
        if (skippedCount > 0) lines.add('纯文本 $skippedCount 项');
      }
      if (states > 0) lines.add('状态种类 $states 个');
      return lines;
    }
    return <String>['列表 ${value.length} 项'];
  }
  if (value is Map<String, dynamic>) {
    if (normalizedKey == 'storyboardTable') {
      final rowCount = countProductionStoryboardTableRows(value);
      final sampledRows = _readSummaryInt(value['rowCount']);
      final assetCount = extractProductionReferencedAssetIds(value).length;
      return <String>[
        if (sampledRows > 0 && rowCount > 0) '分镜表抽样 $sampledRows/$rowCount 行',
        if (sampledRows <= 0 && rowCount > 0) '分镜表 $rowCount 行',
        if (assetCount > 0) '关联资产 $assetCount 项',
      ];
    }
    final lines = <String>['对象 keys=${value.keys.length} 个'];
    for (final entry in value.entries) {
      final child = entry.value;
      if (child is List) {
        lines.add('${entry.key}: ${child.length} 项');
      } else if (child is String && child.trim().isNotEmpty) {
        lines.add('${entry.key}: ${child.trim().length} 字');
      }
      if (lines.length >= 4) {
        break;
      }
    }
    return lines;
  }
  return <String>['返回 ${value.runtimeType}'];
}

int _readSummaryInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
