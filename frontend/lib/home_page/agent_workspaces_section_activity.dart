import 'dart:convert';

import 'package:flutter/material.dart';

class AgentWorkspaceActivityPanel extends StatelessWidget {
  const AgentWorkspaceActivityPanel({
    super.key,
    required this.wsLog,
    required this.workspaceAssistantText,
    required this.workspaceLastToolResultLine,
    required this.workspaceWritebackLine,
  });

  final List<String> wsLog;
  final String workspaceAssistantText;
  final String? workspaceLastToolResultLine;
  final String? workspaceWritebackLine;

  String? _extractEventType(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        if (type is String && type.isNotEmpty) {
          return type;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }

  @override
  Widget build(BuildContext context) {
    final latest = wsLog.isEmpty ? null : wsLog.last;
    final eventType = latest == null ? null : _extractEventType(latest);
    final lines = wsLog.reversed.take(20).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('执行动态', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                if (eventType != null)
                  Chip(
                    label: Text('latest: $eventType'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '最新工具结果：$workspaceLastToolResultLine',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (workspaceWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                workspaceWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('最新助手文本', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                _previewText(workspaceAssistantText.trim(), maxChars: 960),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (lines.isEmpty)
              Text('暂无 WS 事件。', style: Theme.of(context).textTheme.bodySmall)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map(
                      (String line) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SelectableText(
                          line,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
