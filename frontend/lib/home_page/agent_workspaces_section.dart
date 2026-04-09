import 'package:flutter/material.dart';

class AgentWorkspacesSection extends StatelessWidget {
  const AgentWorkspacesSection({
    super.key,
    required this.projectIdController,
    required this.scriptIdController,
    required this.agentPromptController,
    required this.flowKeyController,
    required this.loadingScriptWorkspaceRun,
    required this.loadingProductionWorkspaceRun,
    required this.loadingProductionFlowProbe,
    required this.wsLog,
    required this.onRunScriptWorkspace,
    required this.onRunProductionWorkspace,
    required this.onProbeProductionFlow,
  });

  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  final TextEditingController agentPromptController;
  final TextEditingController flowKeyController;
  final bool loadingScriptWorkspaceRun;
  final bool loadingProductionWorkspaceRun;
  final bool loadingProductionFlowProbe;
  final List<String> wsLog;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onRunProductionWorkspace;
  final VoidCallback onProbeProductionFlow;

  @override
  Widget build(BuildContext context) {
    final busy = loadingScriptWorkspaceRun ||
        loadingProductionWorkspaceRun ||
        loadingProductionFlowProbe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Agent workspaces', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: projectIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'project_id'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: scriptIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'script_id'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: agentPromptController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'workspace prompt',
            helperText:
                '用于 script/production 通道的 harness.agent.run 工作流。',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: busy ? null : onRunScriptWorkspace,
              child: Text(
                loadingScriptWorkspaceRun ? '…' : 'Run script workspace',
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onRunProductionWorkspace,
              child: Text(
                loadingProductionWorkspaceRun ? '…' : 'Run production workspace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: flowKeyController,
                decoration: const InputDecoration(
                  labelText: 'get_flowData key',
                  helperText:
                      'script / scriptPlan / assets / storyboardTable / storyboard',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: busy ? null : onProbeProductionFlow,
              child: Text(
                loadingProductionFlowProbe
                    ? '…'
                    : 'Probe production get_flowData',
              ),
            ),
          ],
        ),
        if (wsLog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('workspace ws log', style: Theme.of(context).textTheme.labelLarge),
          ...wsLog.take(10).map(
            (line) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                line,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
