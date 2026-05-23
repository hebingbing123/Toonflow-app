import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';

import '../../../rust_api.dart';

/// Groups status, result summaries, and suggested flow-key hints for production.
class ProductionWorkspaceStatusPanel extends StatelessWidget {
  const ProductionWorkspaceStatusPanel({
    super.key,
    required this.resultSummaryLines,
    required this.onApplySuggestedFlowKey,
    required this.busy,
    this.runningTaskLine,
    this.taskStatusLine,
    this.workspaceLastToolResultLine,
    this.suggestedFlowKeyLine,
  });

  final List<String> resultSummaryLines;
  final VoidCallback onApplySuggestedFlowKey;
  final bool busy;
  final String? runningTaskLine;
  final String? taskStatusLine;
  final String? workspaceLastToolResultLine;
  final String? suggestedFlowKeyLine;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          runningTaskLine ??
              taskStatusLine ??
              l10n.agentWorkspaceProductionIdleHint,
          style: bodySmall,
        ),
        if (workspaceLastToolResultLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            l10n.agentWorkspaceProductionLatestToolResult(
              workspaceLastToolResultLine!,
            ),
            style: bodySmall,
          ),
        ],
        if (resultSummaryLines.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            l10n.agentWorkspaceProductionResultSummary,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          ...resultSummaryLines.map(
            (String line) => Text(line, style: bodySmall),
          ),
        ],
        if (suggestedFlowKeyLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.agentWorkspaceProductionSuggestedFlowKey(
                    suggestedFlowKeyLine!,
                  ),
                  style: bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: busy ? null : onApplySuggestedFlowKey,
                child: Text(l10n.agentWorkspaceProductionUseSuggestedFlowKey),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(l10n.agentWorkspaceProductionWritebackStrategy, style: bodySmall),
      ],
    );
  }
}
