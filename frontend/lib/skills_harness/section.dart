import 'package:flutter/material.dart';

class HarnessSection extends StatelessWidget {
  const HarnessSection({
    super.key,
    required this.loadingHarnessTools,
    required this.loadingSkillsSummary,
    required this.loadingSkillList,
    required this.loadingSkillPreview,
    required this.loadingSkillVersions,
    required this.loadingSkillPut,
    required this.loadingSkillPost,
    required this.loadingSkillDelete,
    required this.rollingBackSkillVersion,
    required this.wsProbesBusy,
    required this.loadingWs,
    required this.loadingWsHarness,
    required this.loadingWsIsolatedEcho,
    required this.loadingWsWasmProbe,
    required this.loadingWsSkillsRead,
    required this.loadingWsHarnessAgent,
    required this.harnessToolsLine,
    required this.skillsAggregateLine,
    required this.skillsListSummary,
    required this.skillMutationLine,
    required this.skillPathController,
    required this.skillContentController,
    required this.wsLog,
    required this.onLoadHarnessTools,
    required this.onLoadSkillsAggregate,
    required this.onLoadSkillList,
    required this.onPreviewSkillFile,
    required this.onShowSkillVersionHistory,
    required this.onPutSkillProbe,
    required this.onPostSkillProbe,
    required this.onDeleteSkillProbe,
    required this.onTestWebSocket,
    required this.onTestHarnessToolWebSocket,
    required this.onTestHarnessIsolatedEchoWebSocket,
    required this.onTestHarnessWasmProbeWebSocket,
    required this.onTestHarnessSkillsReadWebSocket,
    required this.onTestHarnessAgentRunWebSocket,
  });

  final bool loadingHarnessTools;
  final bool loadingSkillsSummary;
  final bool loadingSkillList;
  final bool loadingSkillPreview;
  final bool loadingSkillVersions;
  final bool loadingSkillPut;
  final bool loadingSkillPost;
  final bool loadingSkillDelete;
  final bool rollingBackSkillVersion;
  final bool wsProbesBusy;
  final bool loadingWs;
  final bool loadingWsHarness;
  final bool loadingWsIsolatedEcho;
  final bool loadingWsWasmProbe;
  final bool loadingWsSkillsRead;
  final bool loadingWsHarnessAgent;
  final String? harnessToolsLine;
  final String? skillsAggregateLine;
  final String? skillsListSummary;
  final String? skillMutationLine;
  final TextEditingController skillPathController;
  final TextEditingController skillContentController;
  final List<String> wsLog;
  final VoidCallback onLoadHarnessTools;
  final VoidCallback onLoadSkillsAggregate;
  final VoidCallback onLoadSkillList;
  final VoidCallback onPreviewSkillFile;
  final VoidCallback onShowSkillVersionHistory;
  final VoidCallback onPutSkillProbe;
  final VoidCallback onPostSkillProbe;
  final VoidCallback onDeleteSkillProbe;
  final VoidCallback onTestWebSocket;
  final VoidCallback onTestHarnessToolWebSocket;
  final VoidCallback onTestHarnessIsolatedEchoWebSocket;
  final VoidCallback onTestHarnessWasmProbeWebSocket;
  final VoidCallback onTestHarnessSkillsReadWebSocket;
  final VoidCallback onTestHarnessAgentRunWebSocket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Harness / skills', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingHarnessTools ? null : onLoadHarnessTools,
              child: Text(
                loadingHarnessTools ? '…' : 'GET /api/v1/harness/tools',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillsSummary ? null : onLoadSkillsAggregate,
              child: Text(
                loadingSkillsSummary ? '…' : 'GET /api/v1/skills/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillList ? null : onLoadSkillList,
              child: Text(loadingSkillList ? '…' : 'GET /api/v1/skills'),
            ),
          ],
        ),
        if (harnessToolsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'tools: $harnessToolsLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsAggregateLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'summary: $skillsAggregateLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsListSummary != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            skillsListSummary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: skillPathController,
          decoration: const InputDecoration(
            labelText: 'Skill relative path',
            helperText:
                'POST needs a path that does not exist yet under data/skills',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: skillContentController,
          decoration: const InputDecoration(labelText: 'Body for PUT / POST'),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingSkillPreview ? null : onPreviewSkillFile,
              child: Text(
                loadingSkillPreview ? '…' : 'GET /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillVersions || rollingBackSkillVersion
                  ? null
                  : onShowSkillVersionHistory,
              child: Text(
                loadingSkillVersions
                    ? '…'
                    : rollingBackSkillVersion
                    ? '回滚中…'
                    : '版本历史 / 回滚',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillPut ? null : onPutSkillProbe,
              child: Text(loadingSkillPut ? '…' : 'PUT /api/v1/skills/content'),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillPost ? null : onPostSkillProbe,
              child: Text(
                loadingSkillPost ? '…' : 'POST /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillDelete ? null : onDeleteSkillProbe,
              child: Text(
                loadingSkillDelete ? '…' : 'DELETE /api/v1/skills/content',
              ),
            ),
          ],
        ),
        if (skillMutationLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            skillMutationLine!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestWebSocket,
              child: Text(loadingWs ? '…' : 'WebSocket: attach + LLM stream'),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessToolWebSocket,
              child: Text(
                loadingWsHarness ? '…' : 'WS: harness.tool.invoke (echo)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy
                  ? null
                  : onTestHarnessIsolatedEchoWebSocket,
              child: Text(
                loadingWsIsolatedEcho ? '…' : 'WS: isolated.echo (subprocess)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessWasmProbeWebSocket,
              child: Text(
                loadingWsWasmProbe ? '…' : 'WS: wasm.probe (embedded)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessSkillsReadWebSocket,
              child: Text(
                loadingWsSkillsRead ? '…' : 'WS: skills.read (path field)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessAgentRunWebSocket,
              child: Text(
                loadingWsHarnessAgent
                    ? '…'
                    : 'WS: harness.agent.run (needs LLM key)',
              ),
            ),
          ],
        ),
        if (wsLog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('WS 最近消息:', style: Theme.of(context).textTheme.labelLarge),
          ...wsLog.map(
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
