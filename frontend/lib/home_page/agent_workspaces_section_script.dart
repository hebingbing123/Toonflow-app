import 'dart:convert';

import 'package:flutter/material.dart';

import 'script_workspace_support.dart';

class AgentWorkspacePromptPreset {
  const AgentWorkspacePromptPreset({required this.label, required this.prompt});

  final String label;
  final String prompt;
}

class AgentWorkspaceScriptCard extends StatefulWidget {
  const AgentWorkspaceScriptCard({
    super.key,
    required this.busy,
    required this.scriptPromptController,
    required this.scriptDomainArgsController,
    required this.scriptSubAgentToolController,
    required this.scriptDomainToolPresets,
    required this.scriptSubAgentPresets,
    required this.scriptPromptPresets,
    required this.selectedScriptDomainTool,
    required this.loadingScriptWorkspaceRun,
    required this.loadingScriptDomainProbe,
    required this.loadingScriptSubAgentRun,
    required this.loadingScriptResultWriteback,
    required this.loadingScriptPlanResultWriteback,
    required this.scopeScriptIdText,
    required this.workspaceAssistantText,
    required this.workspaceScriptWritebackSource,
    required this.workspaceScriptWritebackCandidate,
    required this.workspaceScriptPlanWritebackCandidate,
    this.workspaceLastToolName,
    this.workspaceLastToolResultData,
    required this.workspaceWritebackLine,
    required this.onSelectPrompt,
    required this.onScriptDomainToolChanged,
    required this.onRunScriptWorkspace,
    required this.onProbeScriptDomainTool,
    required this.onScriptSubAgentChanged,
    required this.onRunScriptSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackScriptPlanResult,
  });

  final bool busy;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final TextEditingController scriptSubAgentToolController;
  final List<String> scriptDomainToolPresets;
  final List<String> scriptSubAgentPresets;
  final List<AgentWorkspacePromptPreset> scriptPromptPresets;
  final String selectedScriptDomainTool;
  final bool loadingScriptWorkspaceRun;
  final bool loadingScriptDomainProbe;
  final bool loadingScriptSubAgentRun;
  final bool loadingScriptResultWriteback;
  final bool loadingScriptPlanResultWriteback;
  final String scopeScriptIdText;
  final String workspaceAssistantText;
  final String? workspaceScriptWritebackSource;
  final String? workspaceScriptWritebackCandidate;
  final Map<String, dynamic>? workspaceScriptPlanWritebackCandidate;
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final String? workspaceWritebackLine;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onScriptDomainToolChanged;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onProbeScriptDomainTool;
  final ValueChanged<String> onScriptSubAgentChanged;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;

  @override
  State<AgentWorkspaceScriptCard> createState() =>
      _AgentWorkspaceScriptCardState();
}

class _AgentWorkspaceScriptCardState extends State<AgentWorkspaceScriptCard> {
  String? _taskStatusLine;

  bool get _canWriteBackScriptResult =>
      widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true ||
      widget.workspaceAssistantText.trim().isNotEmpty;

  bool get _canWriteBackScriptPlanResult =>
      widget.workspaceScriptPlanWritebackCandidate != null;

  String? get _scriptWritebackSourceLine {
    final source = widget.workspaceScriptWritebackSource?.trim();
    if (source != null && source.isNotEmpty) return source;
    if (widget.workspaceAssistantText.trim().isNotEmpty) {
      return 'assistant stream';
    }
    return null;
  }

  String? get _scriptPlanWritebackLine {
    final candidate = widget.workspaceScriptPlanWritebackCandidate;
    if (candidate == null) return null;
    final data = candidate['data'];
    if (data is! Map<String, dynamic>) return null;
    final scriptRaw = data['script'];
    final scriptCount = scriptRaw is List
        ? scriptRaw.whereType<Map<String, dynamic>>().length
        : 0;
    return 'PlanData source ready: story/adaptation + script rows=$scriptCount';
  }

  Map<String, dynamic>? get _lastToolResultMap {
    final raw = widget.workspaceLastToolResultData;
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  String? get _runningTaskLine {
    if (widget.loadingScriptWorkspaceRun) return '执行中：运行剧本工作流';
    if (widget.loadingScriptDomainProbe) return '执行中：读取剧本上下文';
    if (widget.loadingScriptSubAgentRun) return '执行中：运行子代理';
    if (widget.loadingScriptResultWriteback) return '执行中：写回剧本';
    if (widget.loadingScriptPlanResultWriteback) return '执行中：写回计划数据';
    return null;
  }

  int? get _scopeScriptId {
    final parsed = int.tryParse(widget.scopeScriptIdText.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  void _setTaskStatus(String message) {
    if (!mounted) return;
    setState(() => _taskStatusLine = message);
  }

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

  String? _resolveDropdownValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    if (allowed.isEmpty) return null;
    return allowed.first;
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
          (label: '模板: 当前剧本', args: '{"scriptId":$scriptId}'),
        ];
      case 'get_novel_text':
      case 'get_novel_events':
        return <({String label, String args})>[
          (label: '模板: 小说 ID', args: '{"novelId":1}'),
        ];
      case 'get_planData':
      default:
        return <({String label, String args})>[(label: '模板: 空参数', args: '{}')];
    }
  }

  void _applyToolArgsTemplate(String args, String label) {
    widget.scriptDomainArgsController.text = args;
    _setTaskStatus('已填充参数模板：$label');
  }

  List<String> _buildResultSummaryLines() {
    final lines = <String>[
      'tool=${widget.selectedScriptDomainTool}',
      if (_scriptWritebackSourceLine != null)
        'writebackSource=${_scriptWritebackSourceLine!}',
      if (widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true)
        'scriptCandidate.chars=${widget.workspaceScriptWritebackCandidate!.trim().length}',
      if (widget.workspaceAssistantText.trim().isNotEmpty)
        'assistant.chars=${widget.workspaceAssistantText.trim().length}',
    ];
    final planCandidate = widget.workspaceScriptPlanWritebackCandidate;
    if (planCandidate != null) {
      final data = planCandidate['data'];
      if (data is Map<String, dynamic>) {
        final scriptRows = data['script'];
        if (scriptRows is List) {
          lines.add('plan.scriptRows=${scriptRows.length}');
        }
        if ((data['storySkeleton'] as String?)?.trim().isNotEmpty == true) {
          lines.add('plan.storySkeleton=ready');
        }
        if ((data['adaptationStrategy'] as String?)?.trim().isNotEmpty ==
            true) {
          lines.add('plan.adaptationStrategy=ready');
        }
      }
    }
    lines.addAll(
      summarizeScriptResultSnapshot(
        widget.workspaceLastToolName,
        widget.workspaceLastToolResultData,
      ),
    );
    return lines.take(6).toList(growable: false);
  }

  List<Widget> _buildContextSnapshot(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sections = <Widget>[];
    final planData = widget.workspaceScriptPlanWritebackCandidate;
    final lastToolName = widget.workspaceLastToolName;
    final lastToolResult = _lastToolResultMap;

    void addPreviewCard({
      required String title,
      required String body,
      String? subtitle,
    }) {
      final normalized = body.trim();
      if (normalized.isEmpty) return;
      sections.add(
        Card(
          margin: const EdgeInsets.only(top: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.labelLarge),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle.trim(), style: theme.bodySmall),
                ],
                const SizedBox(height: 6),
                SelectableText(
                  _previewText(normalized, maxChars: 1200),
                  style: theme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (planData != null) {
      final data = planData['data'];
      if (data is Map<String, dynamic>) {
        final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
        final adaptationStrategy =
            (data['adaptationStrategy'] as String?)?.trim() ?? '';
        final scriptRows = (data['script'] is List)
            ? (data['script'] as List).whereType<Map<String, dynamic>>().toList(
                growable: false,
              )
            : const <Map<String, dynamic>>[];
        addPreviewCard(
          title: '故事骨架',
          body: storySkeleton,
          subtitle: '来自 get_planData',
        );
        addPreviewCard(
          title: '改编策略',
          body: adaptationStrategy,
          subtitle: '来自 get_planData',
        );
        if (scriptRows.isNotEmpty) {
          final lines = scriptRows
              .take(4)
              .map((Map<String, dynamic> row) {
                final name =
                    (row['scriptName'] as String?)?.trim().isNotEmpty == true
                    ? (row['scriptName'] as String).trim()
                    : '未命名剧本';
                final content = (row['scriptData'] as String?)?.trim() ?? '';
                final preview = content.isEmpty
                    ? '无正文'
                    : _previewText(content, maxChars: 220);
                return '$name\n$preview';
              })
              .join('\n\n');
          addPreviewCard(
            title: '计划内剧本草稿',
            body: lines,
            subtitle: '最多展示前 4 条 script rows',
          );
        }
      }
    }

    if (lastToolName == 'get_script_content' && lastToolResult != null) {
      addPreviewCard(
        title: '当前剧本正文',
        subtitle: '来自 get_script_content',
        body: (lastToolResult['content'] as String?) ?? '',
      );
    }

    if (lastToolName == 'get_novel_text' && lastToolResult != null) {
      final items = (lastToolResult['items'] is List)
          ? (lastToolResult['items'] as List)
                .whereType<Map<String, dynamic>>()
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (items.isNotEmpty) {
        final lines = items
            .take(4)
            .map((Map<String, dynamic> row) {
              final chapterIndex = row['chapter_index'] ?? row['chapterIndex'];
              final chapter = (row['chapter'] as String?)?.trim() ?? '未命名章节';
              final body =
                  (row['chapter_data'] as String?)?.trim() ??
                  (row['content'] as String?)?.trim() ??
                  '';
              final prefix = chapterIndex is num
                  ? '第 ${chapterIndex.toInt()} 章 · $chapter'
                  : chapter;
              if (body.isEmpty) return prefix;
              return '$prefix\n${_previewText(body, maxChars: 220)}';
            })
            .join('\n\n');
        addPreviewCard(
          title: '小说章节正文',
          subtitle: '来自 get_novel_text，最多展示前 4 条',
          body: lines,
        );
      } else {
        final title = (lastToolResult['title'] as String?)?.trim();
        addPreviewCard(
          title: '小说章节正文',
          subtitle:
              title == null || title.isEmpty ? '来自 get_novel_text' : title,
          body: (lastToolResult['content'] as String?) ?? '',
        );
      }
    }

    if (lastToolName == 'get_novel_events' && lastToolResult != null) {
      final rawEvents = lastToolResult['events'] ?? lastToolResult['items'];
      final events = rawEvents is List
          ? rawEvents.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (events.isNotEmpty) {
        final lines = events
            .take(6)
            .map((Map<String, dynamic> row) {
              final title =
                  (row['title'] as String?)?.trim() ??
                  (row['name'] as String?)?.trim() ??
                  '未命名事件';
              final description =
                  (row['content'] as String?)?.trim() ??
                  (row['detail'] as String?)?.trim() ??
                  (row['description'] as String?)?.trim() ??
                  '';
              if (description.isEmpty) return title;
              return '$title\n${_previewText(description, maxChars: 180)}';
            })
            .join('\n\n');
        addPreviewCard(
          title: '小说事件',
          subtitle: '来自 get_novel_events，最多展示前 6 条',
          body: lines,
        );
      }
    }

    if (sections.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: 8),
      Text('上下文快照', style: theme.labelLarge),
      ...sections,
    ];
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

  Widget _buildPromptTemplates() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.scriptPromptPresets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: widget.busy
                  ? null
                  : () => widget.onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildGuidedTasks() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onScriptDomainToolChanged('get_planData');
                  _probeScriptDomainTool();
                },
          child: const Text('1) 拉取 planData'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onScriptDomainToolChanged('get_script_content');
                  _probeScriptDomainTool();
                },
          child: const Text('2) 拉取剧本正文'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  _applyScriptPromptIfEmpty(
                    '请基于当前剧情计划与上下文生成下一版剧本正文，输出可直接写回的完整内容。',
                  );
                  widget.onScriptSubAgentChanged('run_sub_agent_script');
                  _runScriptSubAgentTool();
                },
          child: const Text('3) 生成剧本草稿'),
        ),
        OutlinedButton(
          onPressed: widget.busy || !_canWriteBackScriptResult
              ? null
              : _writeBackScriptResult,
          child: const Text('4) 写回剧本'),
        ),
      ],
    );
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    final suggestions = buildScriptWorkspaceArgumentSuggestions(
      selectedTool: widget.selectedScriptDomainTool,
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ...templates.map(
          (entry) => ActionChip(
            label: Text(entry.label),
            onPressed: widget.busy
                ? null
                : () => _applyToolArgsTemplate(entry.args, entry.label),
          ),
        ),
        ...suggestions.map(
          (suggestion) => ActionChip(
            label: Text(suggestion.label),
            onPressed: widget.busy
                ? null
                : () => _applyToolArgsTemplate(
                    jsonEncode(suggestion.payload),
                    suggestion.label,
                  ),
          ),
        ),
      ],
    );
  }

  List<ScriptWorkspaceRecipe> _buildWorkspaceRecipes() {
    return buildScriptWorkspaceRecipes(
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
      scopeScriptId: _scopeScriptId,
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
    if (recipe.domainTool == null || recipe.domainTool!.trim().isEmpty) {
      return;
    }
    _probeScriptDomainTool();
  }

  void _runWorkspaceRecipeSubAgent(ScriptWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.subAgentTool == null || recipe.subAgentTool!.trim().isEmpty) {
      return;
    }
    _runScriptSubAgentTool();
  }

  Widget _buildWorkspaceDiagnosis(BuildContext context) {
    final recipes = _buildWorkspaceRecipes();
    if (recipes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('下一步建议', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ...recipes.map(
          (ScriptWorkspaceRecipe recipe) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (recipe.domainTool != null)
                        Chip(label: Text('tool=${recipe.domainTool}')),
                      if (recipe.subAgentTool != null)
                        Chip(label: Text('agent=${recipe.subAgentTool}')),
                      OutlinedButton(
                        onPressed: widget.busy
                            ? null
                            : () => _applyWorkspaceRecipe(recipe),
                        child: const Text('应用建议'),
                      ),
                      if (recipe.domainTool != null)
                        FilledButton.tonal(
                          onPressed: widget.busy
                              ? null
                              : () => _runWorkspaceRecipeDomainTool(recipe),
                          child: const Text('读取上下文'),
                        ),
                      if (recipe.subAgentTool != null)
                        FilledButton(
                          onPressed: widget.busy
                              ? null
                              : () => _runWorkspaceRecipeSubAgent(recipe),
                          child: const Text('运行子代理'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultSummaryLines = _buildResultSummaryLines();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('剧本工作区', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('引导任务', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: 10),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            TextField(
              controller: widget.scriptPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '工作区提示词',
                helperText: '用于剧本通道 harness.agent.run',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runScriptWorkspace,
                  child: Text(
                    widget.loadingScriptWorkspaceRun ? '…' : '运行剧本工作流',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.selectedScriptDomainTool,
                      widget.scriptDomainToolPresets,
                    ),
                    items: widget.scriptDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            widget.onScriptDomainToolChanged(value);
                          },
                    decoration: const InputDecoration(labelText: '剧本域工具'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _probeScriptDomainTool,
                  child: Text(
                    widget.loadingScriptDomainProbe ? '…' : '读取剧本上下文',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: widget.scriptDomainArgsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '剧本工具参数(JSON)',
                      helperText: '可选，例如 {"novelId":1}',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.scriptSubAgentToolController.text.trim(),
                      widget.scriptSubAgentPresets,
                    ),
                    items: widget.scriptSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            widget.onScriptSubAgentChanged(value);
                          },
                    decoration: const InputDecoration(labelText: '剧本子代理工具'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runScriptSubAgentTool,
                  child: Text(widget.loadingScriptSubAgentRun ? '…' : '运行子代理'),
                ),
                FilledButton(
                  onPressed: widget.busy || !_canWriteBackScriptResult
                      ? null
                      : _writeBackScriptResult,
                  child: Text(
                    widget.loadingScriptResultWriteback ? '…' : '写回剧本',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy || !_canWriteBackScriptPlanResult
                      ? null
                      : _writeBackScriptPlanResult,
                  child: Text(
                    widget.loadingScriptPlanResultWriteback ? '…' : '写回计划数据',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildArgumentTemplates(),
            if (_runningTaskLine != null ||
                _taskStatusLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _runningTaskLine ?? _taskStatusLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (resultSummaryLines.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...resultSummaryLines.map(
                (String line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            _buildWorkspaceDiagnosis(context),
            ..._buildContextSnapshot(context),
            if (widget.workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('最新助手结果', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                _previewText(
                  widget.workspaceAssistantText.trim(),
                  maxChars: 720,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_scriptWritebackSourceLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '写回来源：${_scriptWritebackSourceLine!}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_scriptPlanWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _scriptPlanWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (widget.workspaceWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                widget.workspaceWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
