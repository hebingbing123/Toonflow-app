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
    final session = ProjectScriptsWorkbenchSession(scriptList: scriptList);
    final controller = ProjectScriptsWorkbenchController(
      ctx: ctx,
      token: token,
      project: p,
      setDialogState: setDialogState,
      saving: saving,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
      session: session,
    );

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setLocalState) {
              final diagnosis = session.diagnosis(scriptList: scriptList);
              final selectedIds = session.selectedIds();
              final recommendedAction =
                  selectedIds.isEmpty &&
                      diagnosis.recommendedAction !=
                          ScriptBatchWorkbenchRecommendedAction.syncContext
                  ? null
                  : () => controller.runRecommendedAction(setLocalState);

              return ProjectScriptsWorkbenchDialogView(
                model: ProjectScriptsWorkbenchDialogViewModel(
                  localBusy: session.localBusy,
                  infoLine: session.infoLine,
                  filterCtrl: session.filterCtrl,
                  previewRows: session.previewRows,
                  selectedIdsCtrl: session.selectedIdsCtrl,
                  diagnosis: diagnosis,
                  recommendedActionLabel: controller.recommendedActionLabel(),
                  groupSizeCtrl: session.groupSizeCtrl,
                  addCountCtrl: session.addCountCtrl,
                  addPrefixCtrl: session.addPrefixCtrl,
                  addBodyCtrl: session.addBodyCtrl,
                  scriptList: scriptList,
                  scriptTaskLine: scriptTaskLine[0],
                ),
                callbacks: ProjectScriptsWorkbenchDialogViewCallbacks(
                  onReadContext: () => controller.runAction(
                    setLocalState,
                    () => controller.readContext(setLocalState),
                  ),
                  onUsePreviewOrAll: () =>
                      controller.usePreviewOrAll(setLocalState),
                  onReloadScripts: () => controller.runAction(
                    setLocalState,
                    () => controller.reloadScriptsAndStats(setLocalState),
                  ),
                  onRunRecommendedAction: recommendedAction == null
                      ? null
                      : () => controller.runAction(
                          setLocalState,
                          recommendedAction,
                        ),
                  onExportSelected: () => controller.runAction(
                    setLocalState,
                    () => controller.exportSelected(setLocalState),
                  ),
                  onPollSelected: () => controller.runAction(
                    setLocalState,
                    () => controller.pollSelected(setLocalState),
                  ),
                  onExtractSelected: () => controller.runAction(
                    setLocalState,
                    () => controller.extractSelected(setLocalState),
                  ),
                  onBatchCreate: () => controller.runAction(
                    setLocalState,
                    () => controller.batchCreate(setLocalState),
                  ),
                  onClose: () => Navigator.of(dialogCtx).pop(),
                ),
              );
            },
          );
        },
      );
    } finally {
      session.dispose();
    }
  }
}
