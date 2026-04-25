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
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus('拦截：剧本工具参数必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：剧本工具参数 JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.scriptPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空工作区提示词。');
    return false;
  }

  bool _validateScriptProbe() {
    if (widget.selectedScriptDomainTool.trim().isEmpty) {
      _setTaskStatus('拦截：读取前需要选择剧本域工具。');
      return false;
    }
    if (!_validateJsonArgs(widget.scriptDomainArgsController.text)) {
      return false;
    }
    if (widget.selectedScriptDomainTool == 'get_script_content' &&
        _scopeScriptId == null) {
      _setTaskStatus('拦截：get_script_content 需要有效剧本 ID。');
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final raw = widget.scriptDomainArgsController.text.trim();
    final Map<String, dynamic> normalized;
    if (raw.isEmpty) {
      normalized = <String, dynamic>{};
    } else {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _setTaskStatus('拦截：剧本工具参数必须是 JSON object。');
        return false;
      }
      normalized = Map<String, dynamic>.from(decoded);
    }
    if (widget.selectedScriptDomainTool == 'get_script_content') {
      final scriptId = _scopeScriptId;
      if (scriptId == null) {
        _setTaskStatus('拦截：get_script_content 需要有效剧本 ID。');
        return false;
      }
      if (normalized['scriptId'] != scriptId) {
        normalized['scriptId'] = scriptId;
        widget.scriptDomainArgsController.text = jsonEncode(normalized);
        _setTaskStatus(
          '已同步：get_script_content arguments.scriptId -> $scriptId',
        );
      }
      return true;
    }
    widget.scriptDomainArgsController.text = jsonEncode(normalized);
    return true;
  }

  bool _validateSubAgentTool() {
    if (widget.scriptSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus('拦截：运行子代理前需要选择剧本子代理工具。');
      return false;
    }
    return _validatePrompt('运行子代理');
  }

  List<({String label, String args})> _argumentTemplates() {
    switch (widget.selectedScriptDomainTool) {
      case 'get_script_content':
        final scriptId = _scopeScriptId ?? 1;
        return <({String label, String args})>[
          (
            label: '模板: 当前剧本窗口',
            args:
                '{"scriptId":$scriptId,"lineStart":1,"lineEnd":80,"maxChars":2200}',
          ),
          (
            label: '模板: 当前剧本尾段',
            args:
                '{"scriptId":$scriptId,"lineStart":61,"lineEnd":120,"maxChars":1600}',
          ),
        ];
      case 'get_planData':
        return <({String label, String args})>[
          (label: '模板: 骨架片段', args: '{"key":"storySkeleton","maxChars":1600}'),
          (
            label: '模板: 策略片段',
            args: '{"key":"adaptationStrategy","maxChars":1600}',
          ),
        ];
      case 'get_novel_text':
        return <({String label, String args})>[
          (
            label: '模板: 正文窗口',
            args:
                '{"novelId":1,"fields":["numeric_id","chapter","chapter_data"],"lineStart":1,"lineEnd":80,"maxChars":1800}',
          ),
        ];
      case 'get_novel_events':
        return <({String label, String args})>[
          (
            label: '模板: 事件窗口',
            args:
                '{"novelId":1,"fields":["numeric_id","name","detail"],"limit":8,"maxChars":1200}',
          ),
        ];
      default:
        return <({String label, String args})>[(label: '模板: 空参数', args: '{}')];
    }
  }

  void _applyToolArgsTemplate(String args, String label) {
    widget.scriptDomainArgsController.text = args;
    _setTaskStatus('已填充参数模板：$label');
  }

  void _runScriptWorkspace() {
    if (!_validatePrompt('运行剧本工作流')) return;
    widget.onRunScriptWorkspace();
    _setTaskStatus('已触发：运行剧本工作流');
  }

  void _probeScriptDomainTool() {
    if (!_validateScriptProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeScriptDomainTool();
    _setTaskStatus('已触发：读取剧本上下文 (${widget.selectedScriptDomainTool})');
  }

  void _runScriptSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunScriptSubAgentTool();
    final tool = widget.scriptSubAgentToolController.text.trim();
    _setTaskStatus('已触发：运行子代理 ($tool)');
  }

  void _writeBackScriptResult() {
    if (!_canWriteBackScriptResult) {
      _setTaskStatus('拦截：暂无剧本结果可写回。');
      return;
    }
    widget.onWriteBackScriptResult();
    _setTaskStatus('已触发：写回剧本');
  }

  void _writeBackScriptPlanResult() {
    if (!_canWriteBackScriptPlanResult) {
      _setTaskStatus('拦截：暂无 planData 结果可写回。');
      return;
    }
    widget.onWriteBackScriptPlanResult();
    _setTaskStatus('已触发：写回计划数据');
  }

  void _writeBackScriptPlanViaUpdateData() {
    if (!_canWriteBackScriptPlanViaUpdateData) {
      _setTaskStatus('拦截：需要 planId（拉取 get_planData）与 planData。');
      return;
    }
    widget.onWriteBackScriptPlanViaUpdateData();
    _setTaskStatus('已触发：update-data 写回计划行');
  }

  Widget _buildPromptTemplates() {
    return ScriptWorkspacePromptTemplatesPanel(
      busy: widget.busy,
      presets: widget.scriptPromptPresets,
      onSelectPrompt: widget.onSelectPrompt,
    );
  }

  Widget _buildGuidedTasks() {
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
          '请先读取当前集计划与目标章节事件，必要时再补章节正文窗口和上一集尾段，再生成下一版剧本正文并输出可直接写回的完整内容。',
        );
        widget.onScriptSubAgentChanged('run_sub_agent_script');
        _runScriptSubAgentTool();
      },
      onWriteBackScript: _writeBackScriptResult,
    );
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    final suggestions = buildScriptWorkspaceArgumentSuggestions(
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
    _setTaskStatus('已应用任务建议：${recipe.title}');
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
    _setTaskStatus('已应用阶段动作：${stage.title}');
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
