part of '../../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsBatchAddDialog on _HomePageState {
  /// 处理批量新增分镜弹窗，避免主工作台堆叠表单细节。
  Future<void> _openBatchAddStoryboardsDialog({
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required String token,
    required String projectId,
    required int scriptNumericId,
    required List<StoryboardRow> boardsList,
    required List<bool> actionBusy,
    required List<String?> storyboardTaskLine,
    required List<String?> productionSummaryLine,
    required List<bool> productionSummaryLoaded,
  }) async {
    final promptsCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final l10n = resolveAppLocalizationsForErrors(dialogCtx);
          return AlertDialog(
            title: Text(l10n.scriptEditorStoryboardBatchAddDialogTitle),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: promptsCtrl,
                    minLines: 6,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: l10n.scriptEditorStoryboardBatchAddPromptsLabel,
                      helperText:
                          l10n.scriptEditorStoryboardBatchAddPromptsHelper,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          l10n.scriptEditorStoryboardBatchAddUnifiedDurationLabel,
                      helperText:
                          l10n.scriptEditorStoryboardBatchAddUnifiedDurationHelper,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l10n.projectEditorScriptsBatchAddCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(l10n.scriptEditorStoryboardBatchAddConfirmButton),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final flowL10n = resolveAppLocalizationsForErrors(ctx);
      final prompts = promptsCtrl.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (prompts.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              flowL10n.scriptEditorStoryboardBatchAddNeedOnePromptSnackBar,
            ),
          ),
        );
        return;
      }
      final durationText = durationCtrl.text.trim();
      final duration = durationText.isEmpty ? null : int.tryParse(durationText);
      if (durationText.isNotEmpty && duration == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              flowL10n
                  .scriptEditorStoryboardBatchAddUnifiedDurationMustBeIntegerSnackBar,
            ),
          ),
        );
        return;
      }
      if (duration != null && duration <= 0) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              flowL10n
                  .scriptEditorStoryboardBatchAddUnifiedDurationMustBePositiveSnackBar,
            ),
          ),
        );
        return;
      }
      final payload = prompts
          .map(
            (prompt) =>
                StoryboardBatchAddInfoItem(prompt: prompt, duration: duration),
          )
          .toList(growable: false);

      actionBusy[0] = true;
      setBoardsState(() {});
      try {
        final added = await postStoryboardBatchAddInfoV1(
          token,
          projectUuid: projectId,
          scriptId: scriptNumericId,
          storyboards: payload,
        );
        if (!ctx.mounted) return;
        await _reloadScriptStoryboards(
          token: token,
          projectId: projectId,
          scriptNumericId: scriptNumericId,
          boardsList: boardsList,
          ctx: ctx,
          setBoardsState: setBoardsState,
          boardsLoading: actionBusy,
        );
        if (!ctx.mounted) return;
        await _reloadProductionStoryboardSummary(
          l10n: flowL10n,
          token: token,
          projectId: projectId,
          scriptNumericId: scriptNumericId,
          productionSummaryLine: productionSummaryLine,
          productionSummaryLoaded: productionSummaryLoaded,
          productionSummaryLoading: actionBusy,
          setBoardsState: setBoardsState,
        );
        if (!ctx.mounted) return;
        setBoardsState(() {
          storyboardTaskLine[0] = buildStoryboardListFollowUp(
            flowL10n,
            actionSummary:
                flowL10n.scriptEditorStoryboardBatchAddFollowUpSummary(
              added.added,
            ),
            diagnosis: diagnoseStoryboardList(
              flowL10n,
              boards: boardsList,
              productionSummaryLoaded: productionSummaryLoaded[0],
            ),
          );
        });
      } finally {
        actionBusy[0] = false;
        if (ctx.mounted) {
          setBoardsState(() {});
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        actionBusy[0] = false;
        setBoardsState(() {});
        final snackL10n = resolveAppLocalizationsForErrors(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiError(snackL10n, e))),
        );
      }
    } finally {
      promptsCtrl.dispose();
      durationCtrl.dispose();
    }
  }
}
