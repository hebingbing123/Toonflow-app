part of '../../../../../home_page.dart';

extension _HomePageProjectEditorScriptsWorkbench on _HomePageState {
  Future<void> _openProjectScriptsWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) async {
    await openProjectScriptsWorkbenchDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      saving: saving,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
    );
  }
}
