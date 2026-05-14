part of 'card.dart';

extension _AgentWorkspaceScriptCardLogic on _AgentWorkspaceScriptCardState {
  void _applyScriptPromptIfEmpty(String prompt) {
    if (widget.scriptPromptController.text.trim().isNotEmpty) return;
    widget.scriptPromptController.text = prompt;
  }

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }

  bool _validateJsonArgs(String raw) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus(l10n.agentWorkspaceScriptInterceptArgsMustBeJsonObject);
      return false;
    } catch (_) {
      _setTaskStatus(l10n.agentWorkspaceScriptInterceptArgsJsonParseFailed);
      return false;
    }
  }

  bool _validatePrompt(String action) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.scriptPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus(l10n.agentWorkspaceScriptInterceptPromptRequired(action));
    return false;
  }

  bool _validateScriptProbe() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.selectedScriptDomainTool.trim().isEmpty) {
      _setTaskStatus(l10n.agentWorkspaceScriptInterceptSelectDomainToolFirst);
      return false;
    }
    if (!_validateJsonArgs(widget.scriptDomainArgsController.text)) {
      return false;
    }
    if (widget.selectedScriptDomainTool == 'get_script_content' &&
        _scopeScriptId == null) {
      _setTaskStatus(
        l10n.agentWorkspaceScriptInterceptGetScriptContentNeedsScriptId,
      );
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final raw = widget.scriptDomainArgsController.text.trim();
    final Map<String, dynamic> normalized;
    if (raw.isEmpty) {
      normalized = <String, dynamic>{};
    } else {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _setTaskStatus(l10n.agentWorkspaceScriptInterceptArgsMustBeJsonObject);
        return false;
      }
      normalized = Map<String, dynamic>.from(decoded);
    }
    if (widget.selectedScriptDomainTool == 'get_script_content') {
      final scriptId = _scopeScriptId;
      if (scriptId == null) {
        _setTaskStatus(
          l10n.agentWorkspaceScriptInterceptGetScriptContentNeedsScriptId,
        );
        return false;
      }
      if (normalized['scriptId'] != scriptId) {
        normalized['scriptId'] = scriptId;
        widget.scriptDomainArgsController.text = jsonEncode(normalized);
        _setTaskStatus(
          l10n.agentWorkspaceScriptSyncedScriptContentScriptId(
            scriptId.toString(),
          ),
        );
      }
      return true;
    }
    widget.scriptDomainArgsController.text = jsonEncode(normalized);
    return true;
  }

  bool _validateSubAgentTool() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.scriptSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus(l10n.agentWorkspaceScriptInterceptSelectSubAgentToolFirst);
      return false;
    }
    return _validatePrompt(l10n.agentWorkspaceScriptActionRunSubAgent);
  }

  List<({String label, String args})> _argumentTemplates(
    AppLocalizations l10n,
  ) {
    switch (widget.selectedScriptDomainTool) {
      case 'get_script_content':
        final scriptId = _scopeScriptId ?? 1;
        return <({String label, String args})>[
          (
            label: l10n.agentWorkspaceScriptArgTemplateCurrentWindow,
            args:
                '{"scriptId":$scriptId,"lineStart":1,"lineEnd":80,"maxChars":2200}',
          ),
          (
            label: l10n.agentWorkspaceScriptArgTemplateCurrentTail,
            args:
                '{"scriptId":$scriptId,"lineStart":61,"lineEnd":120,"maxChars":1600}',
          ),
          if ((_scopeScriptId ?? 1) > 1)
            (
              label: l10n.agentWorkspaceScriptArgTemplatePreviousEpisodeTail,
              args:
                  '{"relativeOffset":-1,"lineStart":61,"lineEnd":120,"maxChars":1600}',
            ),
        ];
      case 'get_planData':
        return <({String label, String args})>[
          (
            label: l10n.agentWorkspaceScriptArgTemplateStorySkeletonSlice,
            args: '{"key":"storySkeleton","maxChars":1600}',
          ),
          (
            label: l10n.agentWorkspaceScriptArgTemplateAdaptationSlice,
            args: '{"key":"adaptationStrategy","maxChars":1600}',
          ),
        ];
      case 'get_novel_text':
        return <({String label, String args})>[
          (
            label: l10n.agentWorkspaceScriptArgTemplateNovelTextWindow,
            args:
                '{"fields":["numeric_id","chapter","chapter_data"],"lineStart":1,"lineEnd":80,"maxChars":1800,"limit":1}',
          ),
        ];
      case 'get_novel_events':
        return <({String label, String args})>[
          (
            label: l10n.agentWorkspaceScriptArgTemplateNovelEventsWindow,
            args:
                '{"fields":["numeric_id","name","detail"],"limit":8,"maxChars":1200}',
          ),
        ];
      default:
        return <({String label, String args})>[
          (label: l10n.agentWorkspaceScriptArgTemplateEmptyArgs, args: '{}'),
        ];
    }
  }

  void _applyToolArgsTemplate(String args, String label) {
    final l10n = resolveAppLocalizationsForErrors(context);
    widget.scriptDomainArgsController.text = args;
    _setTaskStatus(l10n.agentWorkspaceFilledArgTemplate(label));
  }

  void _runScriptWorkspace() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (!_validatePrompt(l10n.agentWorkspaceScriptActionRunWorkflow)) return;
    widget.onRunScriptWorkspace();
    _setTaskStatus(l10n.agentWorkspaceScriptTriggeredRunWorkflow);
  }

  void _probeScriptDomainTool() {
    if (!_validateScriptProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeScriptDomainTool();
    final l10n = resolveAppLocalizationsForErrors(context);
    _setTaskStatus(
      l10n.agentWorkspaceScriptTriggeredProbeContext(
        widget.selectedScriptDomainTool,
      ),
    );
  }

  void _runScriptSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunScriptSubAgentTool();
    final l10n = resolveAppLocalizationsForErrors(context);
    final tool = widget.scriptSubAgentToolController.text.trim();
    _setTaskStatus(l10n.agentWorkspaceScriptTriggeredRunSubAgent(tool));
  }

  void _writeBackScriptResult() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (!_canWriteBackScriptResult) {
      _setTaskStatus(l10n.agentWorkspaceScriptInterceptNoScriptWritebackResult);
      return;
    }
    widget.onWriteBackScriptResult();
    _setTaskStatus(l10n.agentWorkspaceScriptTriggeredWritebackScript);
  }

  void _writeBackScriptPlanResult() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (!_canWriteBackScriptPlanResult) {
      _setTaskStatus(
        l10n.agentWorkspaceScriptInterceptNoPlanDataWritebackResult,
      );
      return;
    }
    widget.onWriteBackScriptPlanResult();
    _setTaskStatus(l10n.agentWorkspaceScriptTriggeredWritebackPlanData);
  }

  void _writeBackScriptPlanViaUpdateData() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (!_canWriteBackScriptPlanViaUpdateData) {
      _setTaskStatus(
        l10n.agentWorkspaceScriptInterceptPlanWritebackNeedsPlanId,
      );
      return;
    }
    widget.onWriteBackScriptPlanViaUpdateData();
    _setTaskStatus(l10n.agentWorkspaceScriptTriggeredPlanRowUpdateData);
  }

  Widget _buildPromptTemplates() {
    return ScriptWorkspacePromptTemplatesPanel(
      busy: widget.busy,
      presets: widget.scriptPromptPresets,
      onSelectPrompt: widget.onSelectPrompt,
    );
  }

  Widget _buildGuidedTasks() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return ScriptWorkspaceGuidedTasksPanel(
      busy: widget.busy,
      canWriteBackScriptResult: _canWriteBackScriptResult,
      onFetchPlanData: () {
        widget.onScriptDomainToolChanged('get_planData');
        widget.scriptDomainArgsController.text =
            '{"key":"storySkeleton","maxChars":1600}';
        _probeScriptDomainTool();
      },
      onFetchScriptContent: () {
        widget.onScriptDomainToolChanged('get_script_content');
        final scriptId = _scopeScriptId ?? 1;
        widget.scriptDomainArgsController.text =
            '{"scriptId":$scriptId,"lineStart":61,"lineEnd":120,"maxChars":1600}';
        _probeScriptDomainTool();
      },
      onGenerateDraft: () {
        _applyScriptPromptIfEmpty(
          l10n.agentWorkspaceScriptGuidedGenerateDraftPrompt,
        );
        widget.onScriptSubAgentChanged('run_sub_agent_script');
        _runScriptSubAgentTool();
      },
      onWriteBackScript: _writeBackScriptResult,
    );
  }

  Widget _buildArgumentTemplates(AppLocalizations l10n) {
    final templates = _argumentTemplates(l10n);
    final suggestions = buildScriptWorkspaceArgumentSuggestions(
      l10n: l10n,
      selectedTool: widget.selectedScriptDomainTool,
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
    );
    return ScriptWorkspaceArgumentTemplatesPanel(
      busy: widget.busy,
      templates: <ScriptWorkspaceArgumentTemplateEntry>[
        ...templates.map(
          (entry) => ScriptWorkspaceArgumentTemplateEntry(
            label: entry.label,
            args: entry.args,
          ),
        ),
        ...suggestions.map(
          (suggestion) => ScriptWorkspaceArgumentTemplateEntry(
            label: suggestion.label,
            args: jsonEncode(suggestion.payload),
          ),
        ),
      ],
      onApplyTemplate: _applyToolArgsTemplate,
    );
  }

  void _applyWorkspaceRecipe(ScriptWorkspaceRecipe recipe) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (recipe.domainTool != null && recipe.domainTool!.trim().isNotEmpty) {
      widget.onScriptDomainToolChanged(recipe.domainTool!.trim());
      widget.scriptDomainArgsController.text = jsonEncode(
        recipe.args ?? <String, dynamic>{},
      );
    }
    if (recipe.subAgentTool != null && recipe.subAgentTool!.trim().isNotEmpty) {
      widget.onScriptSubAgentChanged(recipe.subAgentTool!.trim());
    }
    final prompt = recipe.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.scriptPromptController.text = prompt;
    }
    _setTaskStatus(l10n.agentWorkspaceScriptAppliedRecipe(recipe.title));
  }

  void _runWorkspaceRecipeDomainTool(ScriptWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.domainTool == null || recipe.domainTool!.trim().isEmpty) return;
    _probeScriptDomainTool();
  }

  void _runWorkspaceRecipeSubAgent(ScriptWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.subAgentTool == null || recipe.subAgentTool!.trim().isEmpty) {
      return;
    }
    _runScriptSubAgentTool();
  }

  void _applyWorkspaceStage(ScriptWorkspaceStage stage) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (stage.domainTool != null && stage.domainTool!.trim().isNotEmpty) {
      widget.onScriptDomainToolChanged(stage.domainTool!.trim());
      widget.scriptDomainArgsController.text = jsonEncode(
        stage.args ?? <String, dynamic>{},
      );
    }
    if (stage.subAgentTool != null && stage.subAgentTool!.trim().isNotEmpty) {
      widget.onScriptSubAgentChanged(stage.subAgentTool!.trim());
    }
    final prompt = stage.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.scriptPromptController.text = prompt;
    }
    _setTaskStatus(l10n.agentWorkspaceScriptAppliedStage(stage.title));
  }

  void _runWorkspaceStageDomainTool(ScriptWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.domainTool == null || stage.domainTool!.trim().isEmpty) return;
    _probeScriptDomainTool();
  }

  void _runWorkspaceStageSubAgent(ScriptWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.subAgentTool == null || stage.subAgentTool!.trim().isEmpty) {
      return;
    }
    _runScriptSubAgentTool();
  }
}
