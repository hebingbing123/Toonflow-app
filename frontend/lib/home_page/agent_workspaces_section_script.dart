import 'package:flutter/material.dart';

class AgentWorkspacePromptPreset {
  const AgentWorkspacePromptPreset({required this.label, required this.prompt});

  final String label;
  final String prompt;
}

class AgentWorkspaceScriptCard extends StatelessWidget {
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
    required this.workspaceAssistantText,
    required this.workspaceScriptWritebackSource,
    required this.workspaceScriptWritebackCandidate,
    required this.workspaceScriptPlanWritebackCandidate,
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
  final String workspaceAssistantText;
  final String? workspaceScriptWritebackSource;
  final String? workspaceScriptWritebackCandidate;
  final Map<String, dynamic>? workspaceScriptPlanWritebackCandidate;
  final String? workspaceWritebackLine;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onScriptDomainToolChanged;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onProbeScriptDomainTool;
  final ValueChanged<String> onScriptSubAgentChanged;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;

  bool get _canWriteBackScriptResult =>
      workspaceScriptWritebackCandidate?.trim().isNotEmpty == true ||
      workspaceAssistantText.trim().isNotEmpty;

  bool get _canWriteBackScriptPlanResult =>
      workspaceScriptPlanWritebackCandidate != null;

  String? get _scriptWritebackSourceLine {
    final source = workspaceScriptWritebackSource?.trim();
    if (source != null && source.isNotEmpty) return source;
    if (workspaceAssistantText.trim().isNotEmpty) {
      return 'assistant stream';
    }
    return null;
  }

  String? get _scriptPlanWritebackLine {
    final candidate = workspaceScriptPlanWritebackCandidate;
    if (candidate == null) return null;
    final data = candidate['data'];
    if (data is! Map<String, dynamic>) return null;
    final scriptRaw = data['script'];
    final scriptCount = scriptRaw is List
        ? scriptRaw.whereType<Map<String, dynamic>>().length
        : 0;
    return 'PlanData source ready: story/adaptation + script rows=$scriptCount';
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

  Widget _buildPromptTemplates() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scriptPromptPresets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: busy ? null : () => onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Script workspace', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            TextField(
              controller: scriptPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'workspace prompt',
                helperText: '用于 script 通道 harness.agent.run',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: busy ? null : onRunScriptWorkspace,
                  child: Text(loadingScriptWorkspaceRun ? '…' : 'Run script'),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      selectedScriptDomainTool,
                      scriptDomainToolPresets,
                    ),
                    items: scriptDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            onScriptDomainToolChanged(value);
                          },
                    decoration: const InputDecoration(labelText: 'script domain tool'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onProbeScriptDomainTool,
                  child: Text(loadingScriptDomainProbe ? '…' : 'Probe script data'),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: scriptDomainArgsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'script tool arguments(JSON)',
                      helperText: '可选，例如 {"novelId":1}',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      scriptSubAgentToolController.text.trim(),
                      scriptSubAgentPresets,
                    ),
                    items: scriptSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            onScriptSubAgentChanged(value);
                          },
                    decoration: const InputDecoration(labelText: 'script sub-agent tool'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onRunScriptSubAgentTool,
                  child: Text(loadingScriptSubAgentRun ? '…' : 'Run sub-agent'),
                ),
                FilledButton(
                  onPressed: busy || !_canWriteBackScriptResult
                      ? null
                      : onWriteBackScriptResult,
                  child: Text(loadingScriptResultWriteback ? '…' : 'Write back to script'),
                ),
                FilledButton.tonal(
                  onPressed: busy || !_canWriteBackScriptPlanResult
                      ? null
                      : onWriteBackScriptPlanResult,
                  child: Text(
                    loadingScriptPlanResultWriteback ? '…' : 'Write back planData',
                  ),
                ),
              ],
            ),
            if (workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('Latest assistant result', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                _previewText(workspaceAssistantText.trim(), maxChars: 720),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_scriptWritebackSourceLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Writeback source: ${_scriptWritebackSourceLine!}',
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
            if (workspaceWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                workspaceWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
