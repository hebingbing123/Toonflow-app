part of '../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsWorkbench on _HomePageState {
  Future<void> _openStoryboardBatchWorkbenchDialog({
    required BuildContext ctx,
    required String token,
    required String projectId,
    required int projectNumericId,
    required int scriptNumericId,
    required List<StoryboardRow> boardsList,
    required StateSetter setBoardsState,
    required List<bool> actionBusy,
  }) async {
    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return _StoryboardBatchWorkbenchDialog(
          token: token,
          projectId: projectId,
          projectNumericId: projectNumericId,
          scriptNumericId: scriptNumericId,
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
