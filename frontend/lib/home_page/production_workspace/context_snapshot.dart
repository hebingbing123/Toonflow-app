import 'dart:convert';

import 'package:flutter/material.dart';

/// Renders the context snapshot cards for the production workspace.
/// Extracted from [AgentWorkspaceProductionCard] to keep file size manageable.
class ProductionContextSnapshotView extends StatelessWidget {
  const ProductionContextSnapshotView({
    super.key,
    required this.workspaceLastToolName,
    required this.workspaceLastToolResultData,
  });

  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  @override
  Widget build(BuildContext context) {
    final result = workspaceLastToolResultData;
    final toolName = workspaceLastToolName?.trim();
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
      String? subtitle,
    }) {
      final normalized = switch (body) {
        String value => value.trim(),
        _ => _prettyJsonEncoder.convert(body).trim(),
      };
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
          subtitle: '来自 $toolName',
          body: value,
        );
      }
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
