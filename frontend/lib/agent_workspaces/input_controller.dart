import 'dart:convert';

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
  final TextEditingController scriptDomainToolController =
      TextEditingController(text: 'get_planData');
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

  void applyScriptRepairFocus({
    int? scriptNumericId,
    String? stage,
    String? suggestedAction,
  }) {
    final normalizedStage = stage?.trim();
    final normalizedAction = suggestedAction?.trim();
    final prefersAdaptationStrategy =
        normalizedStage == 'adaptation_strategy' ||
        normalizedStage == 'director_planning' ||
        normalizedAction == 'rollback_to_director_planning';
    if (prefersAdaptationStrategy) {
      scriptDomainToolController.text = 'get_planData';
      scriptDomainArgsController.text = jsonEncode(<String, dynamic>{
        'key': 'adaptationStrategy',
        'maxChars': 1600,
      });
      scriptSubAgentToolController.text = 'run_sub_agent_adaptationStrategy';
      return;
    }
    scriptDomainToolController.text = 'get_planData';
    scriptDomainArgsController.text = jsonEncode(<String, dynamic>{
      'key': 'storySkeleton',
      'maxChars': 1600,
    });
    scriptSubAgentToolController.text = 'run_sub_agent_storySkeleton';
  }

  void applyProductionStoryboardFocus({
    int? scriptNumericId,
    int? storyboardNumericId,
    String? suggestedAction,
  }) {
    productionFlowKeyController.text = 'storyboard';
    final normalizedAction = suggestedAction?.trim();
    final storyboardIds = storyboardNumericId != null && storyboardNumericId > 0
        ? <int>[storyboardNumericId]
        : const <int>[];
    final usesStoryboardGenerationTool =
        normalizedAction == 'retry_video_generation' ||
        normalizedAction == 'regenerate_storyboard';
    final usesStoryboardPanelSubAgent =
        normalizedAction == 'patch_storyboard_items' ||
        normalizedAction == 'update_character_anchor' ||
        normalizedAction == 'adjust_video_prompt';

    if (usesStoryboardGenerationTool) {
      productionDomainToolController.text = 'generate_storyboard';
      productionDomainArgsController.text = jsonEncode(<String, dynamic>{
        'ids': storyboardIds.isEmpty ? <int>[1] : storyboardIds,
      });
      productionSubAgentToolController.text = 'run_sub_agent_storyboard_gen';
    } else {
      productionDomainToolController.text = 'get_flowData';
      productionDomainArgsController.text = jsonEncode(<String, dynamic>{
        'key': 'storyboard',
        'fields': <String>[
          'id',
          'index',
          'duration',
          'src',
          'state',
          'associateAssetsIds',
          'shouldGenerateImage',
        ],
        if (storyboardIds.isNotEmpty) 'ids': storyboardIds else 'limit': 12,
        if (scriptNumericId != null && scriptNumericId > 0)
          'scriptId': scriptNumericId,
      });
      if (usesStoryboardPanelSubAgent) {
        productionSubAgentToolController.text =
            'run_sub_agent_storyboard_panel';
      }
    }

    productionSubAgentArgsController.text = jsonEncode(<String, dynamic>{
      if (storyboardIds.isNotEmpty) 'storyboardIds': storyboardIds,
    });
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
    scriptDomainToolController.dispose();
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
