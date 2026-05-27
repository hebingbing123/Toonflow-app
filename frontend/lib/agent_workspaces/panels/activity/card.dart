import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../design_system/components/studio_chip.dart';

import '../../../design_system/components/studio_empty_state.dart';
import '../../../design_system/tokens.dart';
import '../../../l10n/studio_code_labels.dart';
import '../../../rust_api.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    final latest = wsLog.isEmpty ? null : wsLog.last;
    final eventType = latest == null ? null : _extractEventType(latest);
    final lines = wsLog.reversed.take(20).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  l10n.agentWorkspaceActivityTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: StudioSpacing.xs),
                if (eventType != null)
                  StudioChip(
                    label: Text(
                      l10n.agentWorkspaceActivityLatest(
                        studioHarnessWsEventTypeLabel(l10n, eventType),
                      ),
                    ),
                  ),
              ],
            ),
            if (workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.agentWorkspaceActivityLatestToolResult(
                  workspaceLastToolResultLine!,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (workspaceWritebackLine != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                workspaceWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.agentWorkspaceActivityLatestAssistantText,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: StudioSpacing.xs),
              SelectableText(
                _previewText(workspaceAssistantText.trim(), maxChars: 960),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: StudioSpacing.xs),
            if (lines.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.agentWorkspaceActivityNoWsEvents,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map(
                      (String line) => Padding(
                        padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
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
