part of '../../../home_page.dart';

extension _HomePageScriptEditorStoryboards on _HomePageState {
  Future<void> _reloadProductionStoryboardSummary({
    required AppLocalizations l10n,
    required String token,
    required String projectId,
    required int scriptNumericId,
    required List<String?> productionSummaryLine,
    required List<bool> productionSummaryLoaded,
    required List<bool> productionSummaryLoading,
    required List<String?> productionDataVersion,
    required StateSetter setBoardsState,
  }) async {
    productionSummaryLoading[0] = true;
    setBoardsState(() {});
    try {
      final response = await postProductionGetStoryboardDataV1(
        token,
        projectUuid: projectId,
        scriptId: scriptNumericId,
        clientDataVersion: productionDataVersion[0],
      );
      if (response.unchanged) {
        productionSummaryLoaded[0] = true;
        return;
      }
      if (response.dataVersion != null && response.dataVersion!.isNotEmpty) {
        productionDataVersion[0] = response.dataVersion;
      }
      final unknown = l10n.scriptEditorStoryboardsStateFallback;
      final preview = response.data
          .take(4)
          .map(
            (item) {
              final raw = (item.state ?? '').trim();
              final state = raw.isEmpty ? unknown : raw;
              return '#${item.id}:$state';
            },
          )
          .join(', ');
      productionSummaryLine[0] = response.data.isEmpty
          ? l10n.scriptEditorStoryboardsProductionEmptyData
          : l10n.scriptEditorStoryboardsProductionSummaryLine(
              response.data.length,
              preview,
              response.data.length > 4 ? '…' : '',
            );
      productionSummaryLoaded[0] = true;
    } catch (e) {
      productionSummaryLoaded[0] = false;
      productionSummaryLine[0] = l10n.scriptEditorStoryboardsProductionReadFailed(
        describeUserVisibleApiError(l10n, e),
      );
    } finally {
      productionSummaryLoading[0] = false;
      setBoardsState(() {});
    }
  }

  Future<List<StoryboardRow>> _reloadScriptStoryboards({
    required String token,
    required String projectId,
    required int scriptNumericId,
    required List<StoryboardRow> boardsList,
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required List<bool> boardsLoading,
  }) async {
    boardsLoading[0] = true;
    setBoardsState(() {});
    try {
      final fresh = await fetchStoryboardsForProjectScript(
        token,
        projectId,
        scriptNumericId,
      );
      boardsList
        ..clear()
        ..addAll(fresh);
      return fresh;
    } finally {
      boardsLoading[0] = false;
      if (ctx.mounted) {
        setBoardsState(() {});
      }
    }
  }

  Future<void> _openScriptStoryboardsDialog({
    required String token,
    required String projectId,
    required int scriptNumericId,
  }) async {
    try {
      final boards = await fetchStoryboardsForProjectScript(
        token,
        projectId,
        scriptNumericId,
      );
      if (!mounted) return;
      final boardsList = List<StoryboardRow>.from(boards);
      await showDialog<void>(
        context: context,
        builder: (ctx2) {
          final boardsLoading = <bool>[false];
          final actionBusy = <bool>[false];
          final productionSummaryLoading = <bool>[false];
          final productionSummaryLoaded = <bool>[false];
          final autoRefreshQueued = <bool>[false];
          final productionSummaryLine = <String?>[null];
          final productionDataVersion = <String?>[null];
          final storyboardTaskLine = <String?>[null];
          return StatefulBuilder(
            builder: (ctx2, setBoardsState) {
              if (!autoRefreshQueued[0]) {
                autoRefreshQueued[0] = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!ctx2.mounted) return;
                  await _reloadProductionStoryboardSummary(
                    l10n: resolveAppLocalizationsForErrors(ctx2),
                    token: token,
                    projectId: projectId,
                    scriptNumericId: scriptNumericId,
                    productionSummaryLine: productionSummaryLine,
                    productionSummaryLoaded: productionSummaryLoaded,
                    productionSummaryLoading: productionSummaryLoading,
                    productionDataVersion: productionDataVersion,
                    setBoardsState: setBoardsState,
                  );
                });
              }
              final l10n = resolveAppLocalizationsForErrors(ctx2);
              final diagnosis = diagnoseStoryboardList(
                l10n,
                boards: boardsList,
                productionSummaryLoaded: productionSummaryLoaded[0],
              );
              return StoryboardsWorkbenchDialogView(
                model: StoryboardsWorkbenchDialogViewModel(
                  boardsList: boardsList,
                  diagnosis: diagnosis,
                  productionSummaryLine: productionSummaryLine[0],
                  storyboardTaskLine: storyboardTaskLine[0],
                  actionBusy: actionBusy[0],
                  boardsLoading: boardsLoading[0],
                  productionSummaryLoading: productionSummaryLoading[0],
                ),
                callbacks: StoryboardsWorkbenchDialogViewCallbacks(
                  onAddStoryboard: actionBusy[0] || boardsLoading[0]
                      ? null
                      : () => _openAddStoryboardDialog(
                          ctx: ctx2,
                          setBoardsState: setBoardsState,
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          boardsList: boardsList,
                          actionBusy: actionBusy,
                          storyboardTaskLine: storyboardTaskLine,
                          productionSummaryLine: productionSummaryLine,
                          productionSummaryLoaded: productionSummaryLoaded,
                          productionDataVersion: productionDataVersion,
                        ),
                  onBatchAddStoryboards: actionBusy[0] || boardsLoading[0]
                      ? null
                      : () => _openBatchAddStoryboardsDialog(
                          ctx: ctx2,
                          setBoardsState: setBoardsState,
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          boardsList: boardsList,
                          actionBusy: actionBusy,
                          storyboardTaskLine: storyboardTaskLine,
                          productionSummaryLine: productionSummaryLine,
                          productionSummaryLoaded: productionSummaryLoaded,
                          productionDataVersion: productionDataVersion,
                        ),
                  onReloadBoards: actionBusy[0] || boardsLoading[0]
                      ? null
                      : () => _reloadScriptStoryboards(
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          boardsList: boardsList,
                          ctx: ctx2,
                          setBoardsState: setBoardsState,
                          boardsLoading: boardsLoading,
                        ),
                  onOpenBatchWorkbench: actionBusy[0] || boardsLoading[0]
                      ? null
                      : () async {
                          await _openStoryboardBatchWorkbenchDialog(
                            ctx: ctx2,
                            token: token,
                            projectId: projectId,
                            scriptNumericId: scriptNumericId,
                            boardsList: boardsList,
                            setBoardsState: setBoardsState,
                            actionBusy: actionBusy,
                          );
                          if (!ctx2.mounted) return;
                          await _reloadScriptStoryboards(
                            token: token,
                            projectId: projectId,
                            scriptNumericId: scriptNumericId,
                            boardsList: boardsList,
                            ctx: ctx2,
                            setBoardsState: setBoardsState,
                            boardsLoading: boardsLoading,
                          );
                          if (!ctx2.mounted) return;
                          await _reloadProductionStoryboardSummary(
                            l10n: resolveAppLocalizationsForErrors(ctx2),
                            token: token,
                            projectId: projectId,
                            scriptNumericId: scriptNumericId,
                            productionSummaryLine: productionSummaryLine,
                            productionSummaryLoaded: productionSummaryLoaded,
                            productionSummaryLoading: productionSummaryLoading,
                            productionDataVersion: productionDataVersion,
                            setBoardsState: setBoardsState,
                          );
                        },
                  onReloadProductionSummary:
                      actionBusy[0] || productionSummaryLoading[0]
                      ? null
                      : () => _reloadProductionStoryboardSummary(
                          l10n: resolveAppLocalizationsForErrors(ctx2),
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          productionSummaryLine: productionSummaryLine,
                          productionSummaryLoaded: productionSummaryLoaded,
                          productionSummaryLoading: productionSummaryLoading,
                          productionDataVersion: productionDataVersion,
                          setBoardsState: setBoardsState,
                        ),
                  onOpenStoryboard: (board) async {
                    await _openStoryboardEditor(
                      token,
                      board.numericId,
                      projectId: projectId,
                      scriptNumericId: scriptNumericId,
                      onStoryboardTreeMutated: () async {
                        await _reloadScriptStoryboards(
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          boardsList: boardsList,
                          ctx: ctx2,
                          setBoardsState: setBoardsState,
                          boardsLoading: boardsLoading,
                        );
                        if (!ctx2.mounted) return;
                        await _reloadProductionStoryboardSummary(
                          l10n: resolveAppLocalizationsForErrors(ctx2),
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          productionSummaryLine: productionSummaryLine,
                          productionSummaryLoaded: productionSummaryLoaded,
                          productionSummaryLoading: productionSummaryLoading,
                          productionDataVersion: productionDataVersion,
                          setBoardsState: setBoardsState,
                        );
                      },
                    );
                  },
                  onClose: () => Navigator.of(ctx2).pop(),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        final snackL10n = resolveAppLocalizationsForErrors(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiError(snackL10n, e))),
        );
      }
    }
  }
}
