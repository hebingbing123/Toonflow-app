part of '../../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsBatchAddDialog on _HomePageState {
  /// 处理批量新增分镜弹窗，避免主工作台堆叠表单细节。
  Future<void> _openBatchAddStoryboardsDialog({
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required String token,
    required String projectId,
    required int projectNumericId,
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
          return AlertDialog(
            title: const Text('批量新增分镜'),
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
                    decoration: const InputDecoration(
                      labelText: '每行一条分镜提示词',
                      helperText: '会忽略空行，并按输入顺序批量创建。',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '统一时长（可选）',
                      helperText: '若填写，会作用于本次全部新增分镜。',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('批量新增'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final prompts = promptsCtrl.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (prompts.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('至少填写一条分镜提示词')));
        return;
      }
      final durationText = durationCtrl.text.trim();
      final duration = durationText.isEmpty ? null : int.tryParse(durationText);
      if (durationText.isNotEmpty && duration == null) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('统一时长必须是整数')));
        return;
      }
      if (duration != null && duration <= 0) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('统一时长必须是正整数')));
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
          projectId: projectNumericId,
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
          token: token,
          projectNumericId: projectNumericId,
          scriptNumericId: scriptNumericId,
          productionSummaryLine: productionSummaryLine,
          productionSummaryLoaded: productionSummaryLoaded,
          productionSummaryLoading: actionBusy,
          setBoardsState: setBoardsState,
        );
        if (!ctx.mounted) return;
        setBoardsState(() {
          storyboardTaskLine[0] = buildStoryboardListFollowUp(
            actionSummary: '已批量新增 ${added.added} 条分镜。',
            diagnosis: diagnoseStoryboardList(
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
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        actionBusy[0] = false;
        setBoardsState(() {});
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        actionBusy[0] = false;
        setBoardsState(() {});
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      promptsCtrl.dispose();
      durationCtrl.dispose();
    }
  }
}
