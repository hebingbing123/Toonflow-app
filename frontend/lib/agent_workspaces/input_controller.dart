import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class WorkspaceInputController {
  final TextEditingController projectIdController = TextEditingController();

  /// Preferred project key on WebSocket attach (**`app_project.id`**).
  final TextEditingController projectUuidController = TextEditingController();
  final TextEditingController scriptIdController = TextEditingController();

  /// Preferred script key for production attach (**`app_script.id`**).
  final TextEditingController scriptUuidController = TextEditingController();

  /// **`app_project.workspace_id`** for optional **`workspaceUuid`** on WS attach (team / REST 对齐).
  final TextEditingController workspaceUuidController = TextEditingController();
  final TextEditingController scriptPromptController = TextEditingController();
  final TextEditingController scriptDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController productionPromptController =
      TextEditingController();
  final TextEditingController productionFlowKeyController =
      TextEditingController(text: 'scriptPlan');
  final TextEditingController productionDomainToolController =
      TextEditingController(text: 'get_flowData');
  final TextEditingController productionDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController scriptSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_storySkeleton');
  final TextEditingController productionSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_director_plan');
  final TextEditingController productionSubAgentArgsController =
      TextEditingController(text: '{}');

  void applyProjectScope(
    int projectNumericId, {
    int? scriptNumericId,
    String? projectUuid,
    String? scriptUuid,
    String? workspaceId,
  }) {
    projectIdController.text = projectNumericId.toString();
    final u = projectUuid?.trim();
    if (u != null && u.isNotEmpty) {
      projectUuidController.text = u;
    } else {
      projectUuidController.clear();
    }
    final w = workspaceId?.trim();
    if (w != null && w.isNotEmpty) {
      workspaceUuidController.text = w;
    } else {
      workspaceUuidController.clear();
    }
    if (scriptNumericId != null && scriptNumericId > 0) {
      scriptIdController.text = scriptNumericId.toString();
    } else {
      scriptIdController.clear();
    }
    if (scriptUuid != null) {
      final su = scriptUuid.trim();
      if (su.isEmpty) {
        scriptUuidController.clear();
      } else {
        scriptUuidController.text = su;
      }
    } else {
      scriptUuidController.clear();
    }
  }

  void applyProjectScopeRef({
    int? projectNumericId,
    int? scriptNumericId,
    String? projectUuid,
    String? scriptUuid,
    String? workspaceId,
  }) {
    if (projectNumericId != null && projectNumericId > 0) {
      projectIdController.text = projectNumericId.toString();
    } else {
      projectIdController.clear();
    }
    final u = projectUuid?.trim();
    if (u != null && u.isNotEmpty) {
      projectUuidController.text = u;
    } else {
      projectUuidController.clear();
    }
    final w = workspaceId?.trim();
    if (w != null && w.isNotEmpty) {
      workspaceUuidController.text = w;
    } else {
      workspaceUuidController.clear();
    }
    if (scriptNumericId != null && scriptNumericId > 0) {
      scriptIdController.text = scriptNumericId.toString();
    } else {
      scriptIdController.clear();
    }
    if (scriptUuid != null) {
      final su = scriptUuid.trim();
      if (su.isEmpty) {
        scriptUuidController.clear();
      } else {
        scriptUuidController.text = su;
      }
    } else {
      scriptUuidController.clear();
    }
  }

  void clearScriptScope() {
    scriptIdController.clear();
    scriptUuidController.clear();
  }

  void applySuggestedProductionFlowKey(String? flowKey) {
    final normalized = flowKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    productionFlowKeyController.text = normalized;
  }

  void applyLocalizedPromptDefaults(AppLocalizations l10n) {
    scriptPromptController.text = l10n.agentWorkspaceDefaultScriptPrompt;
    productionPromptController.text =
        l10n.agentWorkspaceDefaultProductionPrompt;
  }

  void dispose() {
    projectIdController.dispose();
    projectUuidController.dispose();
    workspaceUuidController.dispose();
    scriptIdController.dispose();
    scriptUuidController.dispose();
    scriptPromptController.dispose();
    scriptDomainArgsController.dispose();
    productionPromptController.dispose();
    productionFlowKeyController.dispose();
    productionDomainToolController.dispose();
    productionDomainArgsController.dispose();
    scriptSubAgentToolController.dispose();
    productionSubAgentToolController.dispose();
    productionSubAgentArgsController.dispose();
  }
}
