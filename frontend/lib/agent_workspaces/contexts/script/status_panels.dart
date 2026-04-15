import 'package:flutter/material.dart';

/// Groups status, result summary, and writeback snapshots for the script workspace.
class ScriptWorkspaceStatusPanel extends StatelessWidget {
  const ScriptWorkspaceStatusPanel({
    super.key,
    required this.resultSummaryLines,
    required this.workspaceAssistantText,
    required this.previewAssistantText,
    this.runningTaskLine,
    this.taskStatusLine,
    this.scriptWritebackSourceLine,
    this.scriptPlanWritebackLine,
    this.workspaceWritebackLine,
  });

  final List<String> resultSummaryLines;
  final String workspaceAssistantText;
  final String Function(String value, {required int maxChars}) previewAssistantText;
  final String? runningTaskLine;
  final String? taskStatusLine;
  final String? scriptWritebackSourceLine;
  final String? scriptPlanWritebackLine;
  final String? workspaceWritebackLine;

  @override
  Widget build(BuildContext context) {
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (runningTaskLine != null || taskStatusLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(runningTaskLine ?? taskStatusLine!, style: bodySmall),
        ],
        if (resultSummaryLines.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ...resultSummaryLines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: bodySmall),
            ),
          ),
        ],
        if (workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('最新助手结果', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(
            previewAssistantText(workspaceAssistantText.trim(), maxChars: 720),
            style: bodySmall,
          ),
        ],
        if (scriptWritebackSourceLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text('写回来源：$scriptWritebackSourceLine', style: bodySmall),
        ],
        if (scriptPlanWritebackLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(scriptPlanWritebackLine!, style: bodySmall),
        ],
        if (workspaceWritebackLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(workspaceWritebackLine!, style: bodySmall),
        ],
      ],
    );
  }
}
