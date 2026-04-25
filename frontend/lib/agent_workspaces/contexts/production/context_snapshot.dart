import 'dart:convert';

import 'package:flutter/material.dart';

import 'flow_logic.dart';
import 'support.dart';

/// Renders the context snapshot cards for the production workspace.
/// Extracted from [AgentWorkspaceProductionCard] to keep file size manageable.
class ProductionContextSnapshotView extends StatelessWidget {
  const ProductionContextSnapshotView({
    super.key,
    required this.workspaceLastToolName,
    required this.workspaceLastToolResultData,
    required this.workspaceSuggestedFlowKey,
  });

  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final String? workspaceSuggestedFlowKey;

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  String _buildPreviewBody(Object body, {String? flowKey}) {
    final normalizedKey = flowKey?.trim() ?? '';
    final summary = summarizeProductionFlowValue(
      body,
      flowKey: normalizedKey,
    ).join(' · ');
    final digest = switch (normalizedKey) {
      'script' => _scriptDigest(body),
      'scriptPlan' => _scriptPlanDigest(body),
      'storyboardTable' => _storyboardTableDigest(body),
      'storyboard' => _storyboardDigest(body),
      _ => switch (body) {
          String value => value.trim(),
          _ => _prettyJsonEncoder.convert(body).trim(),
        },
    };
    if (summary.isEmpty) return digest;
    if (digest.isEmpty || digest == summary) return summary;
    return '$summary\n\n$digest';
  }

  String _plainTextDigest(String value, {int maxLines = 6, int maxChars = 360}) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(maxLines)
        .toList(growable: false);
    if (lines.isEmpty) {
      return value.trim();
    }
    return _previewText(lines.join('\n'), maxChars: maxChars);
  }

  String _scriptDigest(Object body) {
    if (body is! String) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    return _plainTextDigest(body, maxLines: 8, maxChars: 420);
  }

  String _scriptPlanDigest(Object body) {
    if (body is! String) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    final sections = summarizeProductionScriptPlanSections(body);
    if (sections.isNotEmpty) {
      return sections.join('\n');
    }
    return _plainTextDigest(body, maxLines: 8, maxChars: 420);
  }

  String _storyboardTableDigest(Object body) {
    final rows = switch (body) {
      String value => parseProductionStoryboardTableMarkdown(value),
      Map<String, dynamic> value => (value['rows'] is List)
          ? (value['rows'] as List)
                .whereType<Map<String, dynamic>>()
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      _ => const <Map<String, dynamic>>[],
    };
    if (rows.isEmpty) {
      return switch (body) {
        String value => value.trim(),
        _ => _prettyJsonEncoder.convert(body).trim(),
      };
    }
    return rows.take(4).map(_formatStoryboardTableRow).join('\n\n');
  }

  String _storyboardDigest(Object body) {
    if (body is! List) {
      return switch (body) {
        String value => value.trim(),
        _ => _prettyJsonEncoder.convert(body).trim(),
      };
    }
    final rows = body.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    final missingRows = rows
        .where((row) {
          return productionStoryboardEntryNeedsImageGeneration(row) &&
              !productionFlowEntryHasMediaResult(row);
        })
        .take(4)
        .map(_formatStoryboardRow)
        .toList(growable: false);
    if (missingRows.isNotEmpty) {
      return missingRows.join('\n\n');
    }
    return rows.take(4).map(_formatStoryboardRow).join('\n\n');
  }

  String _reviewDigest(ProductionSupervisionReview review) {
    final lines = <String>[
      '目标: ${review.target}',
      '评级: ${review.grade}',
      '问题: 严重 ${review.severeCount} / 中等 ${review.mediumCount} / 轻微 ${review.minorCount}',
      '下一步: ${review.nextAction}',
      if (review.assetIds.isNotEmpty) '聚焦资产: ${review.assetIds.join(', ')}',
      if (review.storyboardIds.isNotEmpty)
        '聚焦镜头: ${review.storyboardIds.join(', ')}',
      if (review.summary.isNotEmpty) '结论: ${review.summary}',
    ];
    return lines.join('\n');
  }

  String _formatStoryboardTableRow(Map<String, dynamic> row) {
    final id = _readNumericId(
      row['id'] ?? row['numeric_id'] ?? row['numericId'] ?? row['storyboardId'],
    );
    final scene = (row['scene'] as String?)?.trim() ?? '';
    final description = (row['description'] as String?)?.trim() ?? '';
    final duration = (row['duration'] as String?)?.trim() ?? '';
    final assetIds = extractProductionReferencedAssetIds(<String, dynamic>{
      'rows': <Map<String, dynamic>>[row],
    });
    final lines = <String>[
      if (id != null) '镜头 #$id',
      if (scene.isNotEmpty) '场景: $scene',
      if (duration.isNotEmpty) '时长: $duration',
      if (description.isNotEmpty) _previewText(description, maxChars: 180),
      if (assetIds.isNotEmpty) '资产: ${assetIds.join(', ')}',
    ];
    return lines.join('\n');
  }

  String _formatStoryboardRow(Map<String, dynamic> row) {
    final id = _readNumericId(
      row['id'] ?? row['numeric_id'] ?? row['numericId'] ?? row['storyboardId'],
    );
    final state = (row['state'] as String?)?.trim() ?? '';
    final duration = switch (row['duration']) {
      String value => value.trim(),
      num value => value.toString(),
      _ => '',
    };
    final prompt = (row['prompt'] as String?)?.trim() ?? '';
    final assetIds = extractProductionReferencedAssetIds(<Map<String, dynamic>>[
      row,
    ]);
    final lines = <String>[
      if (id != null) '镜头 #$id',
      if (state.isNotEmpty) '状态: $state',
      if (duration.isNotEmpty) '时长: $duration',
      if (!productionStoryboardEntryNeedsImageGeneration(row)) '模式: 纯文本',
      if (productionFlowEntryHasMediaResult(row))
        '结果: 已有画面'
      else if (productionStoryboardEntryNeedsImageGeneration(row))
        '结果: 缺帧待补图',
      if (assetIds.isNotEmpty) '资产: ${assetIds.join(', ')}',
      if (prompt.isNotEmpty) _previewText(prompt, maxChars: 180),
    ];
    return lines.join('\n');
  }

  int? _readNumericId(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final result = workspaceLastToolResultData;
    final toolName = workspaceLastToolName?.trim();
    final suggestedFlowKey = workspaceSuggestedFlowKey?.trim();
    if (result is! Map<String, dynamic> ||
        toolName == null ||
        toolName.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).textTheme;
    final sections = <Widget>[];

    void addPreviewCard({
      required String title,
      required Object body,
      String? flowKey,
      String? subtitle,
    }) {
      final normalized = _buildPreviewBody(body, flowKey: flowKey).trim();
      if (normalized.isEmpty) return;
      sections.add(
        Card(
          margin: const EdgeInsets.only(top: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.labelLarge),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle.trim(), style: theme.bodySmall),
                ],
                const SizedBox(height: 6),
                SelectableText(
                  _previewText(normalized, maxChars: 1200),
                  style: theme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = result['data'];
    if (data is Map<String, dynamic>) {
      for (final key in <String>[
        'assets',
        'script',
        'scriptPlan',
        'storyboardTable',
        'storyboard',
      ]) {
        final value = data[key];
        if (value == null) continue;
        addPreviewCard(
          title: 'flow[$key]',
          flowKey: key,
          subtitle: '来自 $toolName',
          body: value,
        );
      }
    } else if (toolName == 'get_flowData' &&
        data != null &&
        suggestedFlowKey != null &&
        suggestedFlowKey.isNotEmpty) {
      addPreviewCard(
        title: 'flow[$suggestedFlowKey]',
        flowKey: suggestedFlowKey,
        subtitle: '来自 $toolName',
        body: data,
      );
    }

    final items = result['items'];
    if (items is List && items.isNotEmpty) {
      addPreviewCard(
        title: '返回列表',
        subtitle: '来自 $toolName',
        body: items.take(6).toList(growable: false),
      );
    }

    final text = result['result'];
    if (text is String && text.trim().isNotEmpty) {
      addPreviewCard(title: '工具返回文本', subtitle: '来自 $toolName', body: text);
    }

    final review = parseProductionSupervisionReview(result);
    if (review != null) {
      addPreviewCard(
        title: '审核摘要',
        subtitle: '来自 $toolName',
        body: _reviewDigest(review),
      );
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('上下文快照', style: theme.labelLarge),
        ...sections,
      ],
    );
  }
}
