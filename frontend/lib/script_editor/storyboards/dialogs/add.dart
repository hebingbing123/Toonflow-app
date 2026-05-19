part of '../../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsAddDialog on _HomePageState {
  /// 处理单条分镜新增弹窗，保持主工作台聚焦列表与编排。
  Future<void> _openAddStoryboardDialog({
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
    required List<String?> productionDataVersion,
  }) async {
    final promptCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    try {
      final confirmed = await showStudioDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          final l10n = resolveAppLocalizationsForErrors(dialogCtx);
          return StudioAlertDialog(
            title: Text(l10n.scriptEditorStoryboardAddDialogTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: promptCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: l10n.scriptEditorStoryboardAddPromptLabel,
                      helperText: l10n.scriptEditorStoryboardAddPromptHelper,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.scriptEditorStoryboardAddDurationOptionalLabel,
                      helperText:
                          l10n.scriptEditorStoryboardAddDurationOptionalHelper,
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
                child: Text(l10n.scriptEditorStoryboardAddConfirmButton),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final flowL10n = resolveAppLocalizationsForErrors(ctx);
      final prompt = promptCtrl.text.trim();
      if (prompt.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              flowL10n.scriptEditorStoryboardAddPromptRequiredSnackBar,
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
              flowL10n.scriptEditorStoryboardDurationMustBeIntegerSnackBar,
            ),
          ),
        );
        return;
      }
      if (duration != null && duration <= 0) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              flowL10n.scriptEditorStoryboardDurationMustBePositiveSnackBar,
            ),
          ),
        );
        return;
      }

      actionBusy[0] = true;
      setBoardsState(() {});
      try {
        final added = await postStoryboardAddV1(
          token,
          projectUuid: projectId,
          scriptId: scriptNumericId,
          prompt: prompt,
          duration: duration,
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
          productionDataVersion: productionDataVersion,
          setBoardsState: setBoardsState,
        );
        if (!ctx.mounted) return;
        setBoardsState(() {
          storyboardTaskLine[0] = buildStoryboardListFollowUp(
            flowL10n,
            actionSummary: flowL10n.scriptEditorStoryboardAddFollowUpSummary(
              added.storyboardId,
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
      promptCtrl.dispose();
      durationCtrl.dispose();
    }
  }
}
