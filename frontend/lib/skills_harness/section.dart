import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../l10n/rust_api_error_format.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';

class HarnessSection extends StatelessWidget {
  const HarnessSection({
    super.key,
    required this.loadingHarnessTools,
    required this.loadingUserWasmValidate,
    required this.loadingUserWasmPersist,
    required this.loadingUserWasmList,
    required this.loadingUserWasmRevoke,
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
    required this.userWasmValidateLine,
    required this.userWasmPersistLine,
    required this.userWasmListLine,
    required this.userWasmRevokeTargetId,
    required this.userWasmRevokeLine,
    required this.skillsAggregateLine,
    required this.skillsListSummary,
    required this.skillMutationLine,
    required this.skillPathController,
    required this.skillContentController,
    required this.wsLog,
    required this.onLoadHarnessTools,
    required this.onValidateUserWasmProbe,
    required this.onPersistUserWasmProbe,
    required this.onLoadUserWasmList,
    required this.onRevokeUserWasmProbe,
    required this.onRevokeUserWasmProbeAndReloadList,
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
  final bool loadingUserWasmValidate;
  final bool loadingUserWasmPersist;
  final bool loadingUserWasmList;
  final bool loadingUserWasmRevoke;
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
  final String? userWasmValidateLine;
  final String? userWasmPersistLine;
  final String? userWasmListLine;
  final String? userWasmRevokeTargetId;
  final String? userWasmRevokeLine;
  final String? skillsAggregateLine;
  final String? skillsListSummary;
  final String? skillMutationLine;
  final TextEditingController skillPathController;
  final TextEditingController skillContentController;
  final List<String> wsLog;
  final VoidCallback onLoadHarnessTools;
  final VoidCallback onValidateUserWasmProbe;
  final VoidCallback onPersistUserWasmProbe;
  final VoidCallback onLoadUserWasmList;
  final VoidCallback onRevokeUserWasmProbe;
  final VoidCallback onRevokeUserWasmProbeAndReloadList;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: StudioSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.skillsHarnessTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.skillsHarnessPrefsTooltip,
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingHarnessTools ? null : onLoadHarnessTools,
              child: Text(
                loadingHarnessTools ? '…' : 'GET /api/v1/harness/tools',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingUserWasmValidate
                  ? null
                  : onValidateUserWasmProbe,
              child: Text(
                loadingUserWasmValidate
                    ? '…'
                    : 'POST /api/v1/harness/user-wasm/validate',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingUserWasmPersist ? null : onPersistUserWasmProbe,
              child: Text(
                loadingUserWasmPersist ? '…' : 'POST /api/v1/harness/user-wasm',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingUserWasmList ? null : onLoadUserWasmList,
              child: Text(
                loadingUserWasmList ? '…' : 'GET /api/v1/harness/user-wasm',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingUserWasmRevoke || userWasmRevokeTargetId == null
                  ? null
                  : onRevokeUserWasmProbe,
              child: Text(
                loadingUserWasmRevoke
                    ? '…'
                    : 'DELETE …/user-wasm/${userWasmRevokeTargetId!.substring(0, 8)}…',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed:
                  (loadingUserWasmRevoke ||
                      loadingUserWasmList ||
                      userWasmRevokeTargetId == null)
                  ? null
                  : onRevokeUserWasmProbeAndReloadList,
              child: Text(
                (loadingUserWasmRevoke || loadingUserWasmList)
                    ? '…'
                    : 'DELETE+GET list …/${userWasmRevokeTargetId!.substring(0, 8)}…',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillsSummary ? null : onLoadSkillsAggregate,
              child: Text(
                loadingSkillsSummary ? '…' : 'GET /api/v1/skills/summary',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillList ? null : onLoadSkillList,
              child: Text(loadingSkillList ? '…' : 'GET /api/v1/skills'),
            ),
          ],
        ),
        if (harnessToolsLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessToolsLabel(harnessToolsLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userWasmValidateLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessUserWasmValidateLabel(userWasmValidateLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userWasmPersistLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessUserWasmPersistLabel(userWasmPersistLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userWasmListLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessUserWasmListLabel(userWasmListLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userWasmRevokeLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessUserWasmRevokeLabel(userWasmRevokeLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsAggregateLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            l10n.skillsHarnessSummaryLabel(skillsAggregateLine!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsListSummary != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            skillsListSummary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: skillPathController,
          decoration: InputDecoration(
            labelText: l10n.skillsHarnessPathLabel,
            helperText: l10n.skillsHarnessPathHelper,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: skillContentController,
          decoration: InputDecoration(labelText: l10n.skillsHarnessBodyLabel),
          maxLines: 4,
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillPreview ? null : onPreviewSkillFile,
              child: Text(
                loadingSkillPreview ? '…' : 'GET /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillVersions || rollingBackSkillVersion
                  ? null
                  : onShowSkillVersionHistory,
              child: Text(
                loadingSkillVersions
                    ? '…'
                    : rollingBackSkillVersion
                    ? l10n.skillsHarnessRollingBack
                    : l10n.skillsHarnessVersions,
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillPut ? null : onPutSkillProbe,
              child: Text(loadingSkillPut ? '…' : 'PUT /api/v1/skills/content'),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillPost ? null : onPostSkillProbe,
              child: Text(
                loadingSkillPost ? '…' : 'POST /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: loadingSkillDelete ? null : onDeleteSkillProbe,
              child: Text(
                loadingSkillDelete ? '…' : 'DELETE /api/v1/skills/content',
              ),
            ),
          ],
        ),
        if (skillMutationLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(
            skillMutationLine!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: wsProbesBusy ? null : onTestWebSocket,
              child: Text(loadingWs ? '…' : 'WebSocket: attach + LLM stream'),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: wsProbesBusy ? null : onTestHarnessToolWebSocket,
              child: Text(
                loadingWsHarness ? '…' : 'WS: harness.tool.invoke (echo)',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: wsProbesBusy
                  ? null
                  : onTestHarnessIsolatedEchoWebSocket,
              child: Text(
                loadingWsIsolatedEcho ? '…' : 'WS: isolated.echo (subprocess)',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: wsProbesBusy ? null : onTestHarnessWasmProbeWebSocket,
              child: Text(
                loadingWsWasmProbe ? '…' : 'WS: wasm.probe (embedded)',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: wsProbesBusy ? null : onTestHarnessSkillsReadWebSocket,
              child: Text(
                loadingWsSkillsRead ? '…' : 'WS: skills.read (path field)',
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
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
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.skillsHarnessWsRecent,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...studioStaggeredChildren(
            wsLog.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
                child: SelectableText(
                  line,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            entranceKey: wsLog.length,
          ),
        ],
      ],
    );
  }
}
