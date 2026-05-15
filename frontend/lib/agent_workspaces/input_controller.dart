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
  final ValueNotifier<int> scriptDomainFocusRevision = ValueNotifier<int>(0);
  final TextEditingController scriptDomainToolController =
      TextEditingController(text: 'get_planData');
  final TextEditingController scriptDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController productionPromptController =
      TextEditingController();
  final ValueNotifier<int> productionDomainFocusRevision = ValueNotifier<int>(
    0,
  );
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

  void _setTrimmedOrClear(TextEditingController controller, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      controller.clear();
      return;
    }
    controller.text = normalized;
  }

  void _setTrimmedIfPresent(TextEditingController controller, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    controller.text = normalized;
  }

  void _setPositiveIntOrClear(
    TextEditingController controller,
    int? numericValue,
  ) {
    if (numericValue != null && numericValue > 0) {
      controller.text = numericValue.toString();
    } else {
      controller.clear();
    }
  }

  void _setRawJsonOrEncodedMap(
    TextEditingController controller, {
    Map<String, dynamic>? jsonMap,
    String? rawJson,
  }) {
    if (rawJson != null) {
      final normalized = rawJson.trim();
      controller.text = normalized.isEmpty ? '{}' : normalized;
      return;
    }
    if (jsonMap != null) {
      controller.text = jsonEncode(jsonMap);
    }
  }

  void _bumpRevision(ValueNotifier<int> revision) {
    revision.value++;
  }

  void _applyProjectScopeValues({
    int? projectNumericId,
    int? scriptNumericId,
    String? projectUuid,
    String? scriptUuid,
    String? workspaceId,
  }) {
    _setPositiveIntOrClear(projectIdController, projectNumericId);
    _setTrimmedOrClear(projectUuidController, projectUuid);
    _setTrimmedOrClear(workspaceUuidController, workspaceId);
    _setPositiveIntOrClear(scriptIdController, scriptNumericId);
    _setTrimmedOrClear(scriptUuidController, scriptUuid);
  }

  void applyProjectScope(
    int projectNumericId, {
    int? scriptNumericId,
    String? projectUuid,
    String? scriptUuid,
    String? workspaceId,
  }) {
    _applyProjectScopeValues(
      projectNumericId: projectNumericId,
      scriptNumericId: scriptNumericId,
      projectUuid: projectUuid,
      scriptUuid: scriptUuid,
      workspaceId: workspaceId,
    );
  }

  void applyProjectScopeRef({
    int? projectNumericId,
    int? scriptNumericId,
    String? projectUuid,
    String? scriptUuid,
    String? workspaceId,
  }) {
    _applyProjectScopeValues(
      projectNumericId: projectNumericId,
      scriptNumericId: scriptNumericId,
      projectUuid: projectUuid,
      scriptUuid: scriptUuid,
      workspaceId: workspaceId,
    );
  }

  void clearScriptScope() {
    scriptIdController.clear();
    scriptUuidController.clear();
  }

  void applySuggestedProductionFlowKey(String? flowKey) {
    _setTrimmedIfPresent(productionFlowKeyController, flowKey);
  }

  void applyScriptDomainFocus({
    required String domainTool,
    Map<String, dynamic>? domainArgs,
    String? rawDomainArgs,
    String? subAgentTool,
    String? prompt,
  }) {
    final normalizedTool = domainTool.trim();
    if (normalizedTool.isEmpty) {
      return;
    }
    scriptDomainToolController.text = normalizedTool;
    _setRawJsonOrEncodedMap(
      scriptDomainArgsController,
      jsonMap: domainArgs,
      rawJson: rawDomainArgs,
    );
    _setTrimmedIfPresent(scriptSubAgentToolController, subAgentTool);
    _setTrimmedIfPresent(scriptPromptController, prompt);
    _bumpRevision(scriptDomainFocusRevision);
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
      applyScriptDomainFocus(
        domainTool: 'get_planData',
        domainArgs: <String, dynamic>{
          'key': 'adaptationStrategy',
          'maxChars': 1600,
        },
        subAgentTool: 'run_sub_agent_adaptationStrategy',
      );
      return;
    }
    applyScriptDomainFocus(
      domainTool: 'get_planData',
      domainArgs: <String, dynamic>{'key': 'storySkeleton', 'maxChars': 1600},
      subAgentTool: 'run_sub_agent_storySkeleton',
    );
  }

  void applyProductionDomainFocus({
    String? flowKey,
    required String domainTool,
    Map<String, dynamic>? domainArgs,
    String? rawDomainArgs,
    String? subAgentTool,
    Map<String, dynamic>? subAgentArgs,
    String? rawSubAgentArgs,
    String? prompt,
  }) {
    _setTrimmedIfPresent(productionFlowKeyController, flowKey);
    final normalizedTool = domainTool.trim();
    if (normalizedTool.isEmpty) {
      return;
    }
    productionDomainToolController.text = normalizedTool;
    _setRawJsonOrEncodedMap(
      productionDomainArgsController,
      jsonMap: domainArgs,
      rawJson: rawDomainArgs,
    );
    _setTrimmedIfPresent(productionSubAgentToolController, subAgentTool);
    _setRawJsonOrEncodedMap(
      productionSubAgentArgsController,
      jsonMap: subAgentArgs,
      rawJson: rawSubAgentArgs,
    );
    _setTrimmedIfPresent(productionPromptController, prompt);
    _bumpRevision(productionDomainFocusRevision);
  }

  void applyProductionStoryboardFocus({
    int? scriptNumericId,
    int? storyboardNumericId,
    String? suggestedAction,
  }) {
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
      applyProductionDomainFocus(
        flowKey: 'storyboard',
        domainTool: 'generate_storyboard',
        domainArgs: <String, dynamic>{
          'ids': storyboardIds.isEmpty ? <int>[1] : storyboardIds,
        },
        subAgentTool: 'run_sub_agent_storyboard_gen',
        subAgentArgs: <String, dynamic>{
          if (storyboardIds.isNotEmpty) 'storyboardIds': storyboardIds,
        },
      );
    } else {
      applyProductionDomainFocus(
        flowKey: 'storyboard',
        domainTool: 'get_flowData',
        domainArgs: <String, dynamic>{
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
        },
        subAgentTool: usesStoryboardPanelSubAgent
            ? 'run_sub_agent_storyboard_panel'
            : null,
        subAgentArgs: <String, dynamic>{
          if (storyboardIds.isNotEmpty) 'storyboardIds': storyboardIds,
        },
      );
    }
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
    scriptDomainFocusRevision.dispose();
    scriptDomainToolController.dispose();
    scriptDomainArgsController.dispose();
    productionPromptController.dispose();
    productionDomainFocusRevision.dispose();
    productionFlowKeyController.dispose();
    productionDomainToolController.dispose();
    productionDomainArgsController.dispose();
    scriptSubAgentToolController.dispose();
    productionSubAgentToolController.dispose();
    productionSubAgentArgsController.dispose();
  }
}
