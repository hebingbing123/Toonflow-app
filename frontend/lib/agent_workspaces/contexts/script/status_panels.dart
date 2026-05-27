import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';

import '../../../rust_api.dart';

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
  final String Function(String value, {required int maxChars})
  previewAssistantText;
  final String? runningTaskLine;
  final String? taskStatusLine;
  final String? scriptWritebackSourceLine;
  final String? scriptPlanWritebackLine;
  final String? workspaceWritebackLine;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (runningTaskLine != null || taskStatusLine != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(runningTaskLine ?? taskStatusLine!, style: bodySmall),
        ],
        if (resultSummaryLines.isNotEmpty) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          ...resultSummaryLines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: StudioSpacing.radiusHairline),
              child: Text(line, style: bodySmall),
            ),
          ),
        ],
        if (workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.agentWorkspaceScriptLatestAssistantResult,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            previewAssistantText(workspaceAssistantText.trim(), maxChars: 720),
            style: bodySmall,
          ),
        ],
        if (scriptWritebackSourceLine != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.agentWorkspaceScriptWritebackSource(
              scriptWritebackSourceLine!,
            ),
            style: bodySmall,
          ),
        ],
        if (scriptPlanWritebackLine != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(scriptPlanWritebackLine!, style: bodySmall),
        ],
        if (workspaceWritebackLine != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(workspaceWritebackLine!, style: bodySmall),
        ],
      ],
    );
  }
}
