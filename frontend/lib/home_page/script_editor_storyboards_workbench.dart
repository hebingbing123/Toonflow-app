part of '../home_page.dart';

extension _HomePageScriptEditorStoryboardsWorkbench on _HomePageState {
  Future<void> _openStoryboardBatchWorkbenchDialog({
    required BuildContext ctx,
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
    required List<StoryboardRow> boardsList,
    required StateSetter setBoardsState,
    required List<bool> actionBusy,
  }) async {
    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return _StoryboardBatchWorkbenchDialog(
          token: token,
          projectLegacyId: projectLegacyId,
          scriptLegacyId: scriptLegacyId,
          boardsList: boardsList,
          onMutationStart: () => setBoardsState(() => actionBusy[0] = true),
          onMutationEnd: () {
            if (ctx.mounted) {
              setBoardsState(() {});
              setBoardsState(() => actionBusy[0] = false);
            }
          },
        );
      },
    );
  }
}
