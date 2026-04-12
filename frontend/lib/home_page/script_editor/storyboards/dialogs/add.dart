part of '../../../home_page.dart';

extension _HomePageScriptEditorStoryboardsAddDialog on _HomePageState {
  /// 处理单条分镜新增弹窗，保持主工作台聚焦列表与编排。
  Future<void> _openAddStoryboardDialog({
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
    final promptCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('新增分镜'),
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
                    decoration: const InputDecoration(
                      labelText: '分镜提示词',
                      helperText: '填写本镜头的画面描述或动作提示。',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时长（可选）',
                      helperText: '整数秒；留空表示由后端默认。',
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
                child: const Text('新增'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final prompt = promptCtrl.text.trim();
      if (prompt.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('分镜提示词不能为空')));
        return;
      }
      final durationText = durationCtrl.text.trim();
      final duration = durationText.isEmpty ? null : int.tryParse(durationText);
      if (durationText.isNotEmpty && duration == null) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('时长必须是整数')));
        return;
      }

      actionBusy[0] = true;
      setBoardsState(() {});
      try {
        final added = await postStoryboardAddV1(
          token,
          projectId: projectNumericId,
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
            actionSummary: '已新增分镜 #${added.storyboardId}。',
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
      promptCtrl.dispose();
      durationCtrl.dispose();
    }
  }
}
