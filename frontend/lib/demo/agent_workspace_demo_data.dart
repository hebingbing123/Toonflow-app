import 'dart:convert';

import '../l10n/rust_api_error_format.dart';

/// Sample agent workspace activity feed for demo mode.
class AgentWorkspaceDemoSnapshot {
  const AgentWorkspaceDemoSnapshot({
    required this.wsLogLines,
    required this.assistantText,
    this.lastToolResultLine,
    this.writebackLine,
    this.suggestedFlowKey,
  });

  final List<String> wsLogLines;
  final String assistantText;
  final String? lastToolResultLine;
  final String? writebackLine;
  final String? suggestedFlowKey;
}

AgentWorkspaceDemoSnapshot buildDemoAgentWorkspaceSnapshot() {
  final l10n = rustApiLookupL10nFromPlatform();
  return AgentWorkspaceDemoSnapshot(
    wsLogLines: <String>[
      '{"type":"session","status":"connected","mode":"demo"}',
      '{"type":"tool_call","name":"list_scripts","status":"completed"}',
      '{"type":"assistant","content":${jsonEncode(l10n.demoAgentWsLogScriptsListed)}}',
      '{"type":"tool_call","name":"list_storyboards","status":"completed"}',
      '{"type":"tool_result","summary":"script_count=2, storyboard_ready=4"}',
      '{"type":"tool_call","name":"short_video_assembly_preview","status":"completed"}',
      '{"type":"assistant","content":${jsonEncode(l10n.demoAgentWsLogAssemblyPreview)}}',
    ],
    assistantText: l10n.demoAgentAssistantBody(l10n.demoStudioProjectDisplayName),
    lastToolResultLine:
        'short_video_assembly_preview → 3 shots, export_ready=true',
    writebackLine: l10n.demoAgentWritebackDisabledLine,
    suggestedFlowKey: 'storyboard_batch_v2',
  );
}
