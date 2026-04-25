part of 'flow_logic.dart';

List<String> summarizeProductionResultSnapshot(
  String? toolName,
  Object? result,
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
    return summarizeProductionFlowValue(data);
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

List<String> summarizeProductionFlowValue(Object? value) {
  if (value == null) {
    return const <String>['当前 flow 为空'];
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>['当前 flow 为空字符串'];
    }
    final lines = '\n'.allMatches(trimmed).length + 1;
    return <String>['文本 ${trimmed.length} 字', '$lines 行'];
  }
  if (value is List) {
    if (value.isEmpty) {
      return const <String>['当前列表为空'];
    }
    final first = value.first;
    if (first is Map<String, dynamic>) {
      final withUrl = value.whereType<Map<String, dynamic>>().where((entry) {
        return productionFlowEntryHasMediaResult(entry);
      }).length;
      final withPrompt = value.whereType<Map<String, dynamic>>().where((entry) {
        final raw = entry['prompt'];
        return raw is String && raw.trim().isNotEmpty;
      }).length;
      final states = value
          .whereType<Map<String, dynamic>>()
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
      if (states > 0) lines.add('状态种类 $states 个');
      return lines;
    }
    return <String>['列表 ${value.length} 项'];
  }
  if (value is Map<String, dynamic>) {
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
