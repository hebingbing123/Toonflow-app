part of '../../../../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    return buildProjectScriptsSection(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      saving: saving,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
      probeActions: _buildProjectScriptsProbeActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptProbeBusy: scriptProbeBusy,
        scriptList: scriptList,
      ),
      openWorkbench: () => _openProjectScriptsWorkbenchDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptTaskBusy: scriptTaskBusy,
        scriptTaskLine: scriptTaskLine,
        scriptList: scriptList,
        statsRef: statsRef,
      ),
      openBatchAddDialog: () => _openBatchAddScriptsDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptTaskLine: scriptTaskLine,
        scriptList: scriptList,
        statsRef: statsRef,
      ),
      openScriptEditor: (script) => _openScriptEditor(
        token,
        script.numericId,
        projectId: p.id,
        projectNumericId: p.numericId,
        onScriptTreeMutated: () async {
          final d = await fetchProjectByProjectId(token, p.id);
          if (!ctx.mounted) return;
          scriptList
            ..clear()
            ..addAll(d.scripts);
          try {
            statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
          } catch (_) {}
          setDialogState(() {});
        },
      ),
    );
  }
}
