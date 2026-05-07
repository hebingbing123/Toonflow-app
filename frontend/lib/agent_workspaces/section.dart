import 'dart:convert';

import 'package:flutter/material.dart';

import 'controls.dart';
import 'contexts/production/support.dart';
import 'prompt_preset.dart';
import 'panels/activity.dart';
import 'panels/production.dart';
import 'panels/script.dart';

part 'section_state.dart';
part 'section_helpers.dart';

class AgentWorkspacesSection extends StatefulWidget {
  const AgentWorkspacesSection({
    super.key,
    this.initialPane = AgentWorkspacePane.script,
    this.showPaneSelector = true,
    this.sectionTitle,
    this.sectionDescription,
    required this.projectIdController,
    required this.scriptIdController,
    this.projectUuidController,
    this.scriptUuidController,
    this.workspaceUuidController,
    required this.scriptPromptController,
    required this.scriptDomainArgsController,
    required this.productionPromptController,
    required this.flowKeyController,
    required this.productionDomainToolController,
    required this.productionDomainArgsController,
    this.productionSubAgentArgsController,
    required this.loadingScriptWorkspaceRun,
    required this.loadingProductionWorkspaceRun,
    required this.loadingScriptDomainProbe,
    required this.loadingProductionFlowProbe,
    required this.loadingScriptSubAgentRun,
    required this.loadingProductionSubAgentRun,
    required this.loadingScriptResultWriteback,
    required this.loadingScriptPlanResultWriteback,
    required this.loadingProductionResultWriteback,
    required this.wsLog,
    required this.workspaceAssistantText,
    required this.workspaceScriptWritebackCandidate,
    required this.workspaceScriptPlanWritebackCandidate,
    required this.workspaceScriptPlanRowId,
    required this.workspaceScriptWritebackSource,
    required this.workspaceLastToolResultLine,
    this.workspaceLastToolName,
    this.workspaceLastToolResultData,
    this.workspaceLastToolArguments,
    required this.workspaceSuggestedFlowKey,
    required this.workspaceWritebackLine,
    required this.onRunScriptWorkspace,
    required this.onRunProductionWorkspace,
    required this.onProbeScriptDomainTool,
    required this.onProbeProductionDomainTool,
    required this.scriptSubAgentToolController,
    required this.productionSubAgentToolController,
    required this.onRunScriptSubAgentTool,
    required this.onRunProductionSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackScriptPlanResult,
    required this.onWriteBackScriptPlanViaUpdateData,
    required this.onWriteBackProductionFlowResult,
    required this.onApplySuggestedFlowKey,
  });

  final AgentWorkspacePane initialPane;
  final bool showPaneSelector;
  final String? sectionTitle;
  final String? sectionDescription;
  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  /// When both **`projectUuidController`** and **`scriptUuidController`** are null, the state creates internal controllers.
  final TextEditingController? projectUuidController;
  final TextEditingController? scriptUuidController;
  /// When **`projectUuidController`** / **`scriptUuidController`** are supplied together, this must be non-null (WS **`workspaceUuid`**).
  final TextEditingController? workspaceUuidController;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final TextEditingController productionPromptController;
  final TextEditingController flowKeyController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final TextEditingController? productionSubAgentArgsController;
  final bool loadingScriptWorkspaceRun;
  final bool loadingProductionWorkspaceRun;
  final bool loadingScriptDomainProbe;
  final bool loadingProductionFlowProbe;
  final bool loadingScriptSubAgentRun;
  final bool loadingProductionSubAgentRun;
  final bool loadingScriptResultWriteback;
  final bool loadingScriptPlanResultWriteback;
  final bool loadingProductionResultWriteback;
  final List<String> wsLog;
  final String workspaceAssistantText;
  final String? workspaceScriptWritebackCandidate;
  final Map<String, dynamic>? workspaceScriptPlanWritebackCandidate;
  final int? workspaceScriptPlanRowId;
  final String? workspaceScriptWritebackSource;
  final String? workspaceLastToolResultLine;
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final Map<String, dynamic>? workspaceLastToolArguments;
  final String? workspaceSuggestedFlowKey;
  final String? workspaceWritebackLine;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onRunProductionWorkspace;
  final void Function(String toolName, String rawArgs) onProbeScriptDomainTool;
  final VoidCallback onProbeProductionDomainTool;
  final TextEditingController scriptSubAgentToolController;
  final TextEditingController productionSubAgentToolController;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onRunProductionSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;
  final VoidCallback onWriteBackScriptPlanViaUpdateData;
  final VoidCallback onWriteBackProductionFlowResult;
  final VoidCallback onApplySuggestedFlowKey;

  @override
  State<AgentWorkspacesSection> createState() => _AgentWorkspacesSectionState();
}
