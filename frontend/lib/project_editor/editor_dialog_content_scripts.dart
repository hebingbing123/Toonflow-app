part of '../../home_page.dart';

extension _HomePageProjectEditorDialogContentScripts on _HomePageState {
  Widget _buildProjectEditorScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
    required List<ScriptBrief> scriptList,
  }) {
    final l10n = AppLocalizations.of(ctx)!;
    return buildProjectScriptsSection(
      ctx: ctx,
      l10n: l10n,
      setDialogState: setDialogState,
      token: token,
      project: p,
      saving: dialogState.saving,
      scriptTaskBusy: dialogState.scriptTaskBusy,
      scriptTaskLine: dialogState.scriptTaskLine,
      scriptList: scriptList,
      statsRef: dialogState.statsRef,
      probeActions: _buildProjectScriptsProbeActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: dialogState.saving,
        scriptProbeBusy: dialogState.scriptProbeBusy,
        scriptList: scriptList,
      ),
      openWorkbench: () => openProjectScriptsWorkbenchDialog(
        ctx: ctx,
        l10n: l10n,
        setDialogState: setDialogState,
        token: token,
        project: p,
        saving: dialogState.saving,
        scriptTaskBusy: dialogState.scriptTaskBusy,
        scriptTaskLine: dialogState.scriptTaskLine,
        scriptList: scriptList,
        statsRef: dialogState.statsRef,
      ),
      openPlanWorkbench: () => _openProjectScriptPlanWorkbenchDialog(
        ctx: ctx,
        token: token,
        project: p,
      ),
      openBatchAddDialog: () => _openBatchAddScriptsDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: dialogState.saving,
        scriptTaskLine: dialogState.scriptTaskLine,
        scriptList: scriptList,
        statsRef: dialogState.statsRef,
      ),
      openScriptEditor: (script) => _openScriptEditor(
        token,
        script.numericId,
        projectId: p.id,
        onScriptTreeMutated: () async {
          final refreshed = await fetchProjectByProjectId(token, p.id);
          if (!ctx.mounted) return;
          setDialogState(() {
            scriptList
              ..clear()
              ..addAll(refreshed.scripts);
          });
          await dialogState.reloadAssetsAndStats(token, p.id, p.numericId);
        },
      ),
    );
  }
}
