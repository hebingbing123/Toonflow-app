part of '../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsBatchWorkbench on _HomePageState {
  /// Opens batch image generation workbench as a single dialog on the storyboard step.
  Future<void> _openStoryboardBatchImageWorkbench({
    required BuildContext context,
    required String token,
    required String projectUuid,
    required int scriptNumericId,
  }) async {
    try {
      final boards = await fetchStoryboardsForProjectScript(
        token,
        projectUuid,
        scriptNumericId,
      );
      if (!context.mounted) return;
      final boardsList = List<StoryboardRow>.from(boards);
      await showStudioDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              return _StoryboardBatchWorkbenchDialog(
                token: token,
                projectId: projectUuid,
                scriptNumericId: scriptNumericId,
                boardsList: boardsList,
                onMutationStart: () => setDialogState(() {}),
                onMutationEnd: () {
                  if (dialogCtx.mounted) setDialogState(() {});
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeUserVisibleApiErrorResolved(context, e)),
          ),
        );
      }
    }
  }
}
