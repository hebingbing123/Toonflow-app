part of '../home_page.dart';

extension _HomePageScriptEditorStoryboards on _HomePageState {
  Future<void> _reloadProductionStoryboardSummary({
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
    required List<String?> productionSummaryLine,
    required List<bool> productionSummaryLoaded,
    required List<bool> productionSummaryLoading,
    required StateSetter setBoardsState,
  }) async {
    productionSummaryLoading[0] = true;
    setBoardsState(() {});
    try {
      final response = await postProductionGetStoryboardDataV1(
        token,
        projectId: projectLegacyId,
        scriptId: scriptLegacyId,
      );
      final preview = response.data
          .take(4)
          .map(
            (item) =>
                '#${item.id}:${(item.state ?? 'unknown').trim().isEmpty ? 'unknown' : item.state}',
          )
          .join(', ');
      productionSummaryLine[0] = response.data.isEmpty
          ? '制作视图当前没有分镜数据'
          : '制作视图 ${response.data.length} 条 · $preview${response.data.length > 4 ? '…' : ''}';
      productionSummaryLoaded[0] = true;
    } on RustApiException catch (e) {
      productionSummaryLoaded[0] = false;
      productionSummaryLine[0] = '制作视图读取失败：$e';
    } catch (e) {
      productionSummaryLoaded[0] = false;
      productionSummaryLine[0] = '制作视图读取失败：$e';
    } finally {
      productionSummaryLoading[0] = false;
      setBoardsState(() {});
    }
  }

  Future<List<StoryboardRow>> _reloadScriptStoryboards({
    required String token,
    required int scriptLegacyId,
    required List<StoryboardRow> boardsList,
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required List<bool> boardsLoading,
  }) async {
    boardsLoading[0] = true;
    setBoardsState(() {});
    try {
      final fresh = await fetchStoryboardsForScript(token, scriptLegacyId);
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

  Future<void> _openAddStoryboardDialog({
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
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
          projectId: projectLegacyId,
          scriptId: scriptLegacyId,
          prompt: prompt,
          duration: duration,
        );
        if (!ctx.mounted) return;
        await _reloadScriptStoryboards(
          token: token,
          scriptLegacyId: scriptLegacyId,
          boardsList: boardsList,
          ctx: ctx,
          setBoardsState: setBoardsState,
          boardsLoading: actionBusy,
        );
        if (!ctx.mounted) return;
        await _reloadProductionStoryboardSummary(
          token: token,
          projectLegacyId: projectLegacyId,
          scriptLegacyId: scriptLegacyId,
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

  Future<void> _openBatchAddStoryboardsDialog({
    required BuildContext ctx,
    required StateSetter setBoardsState,
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
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
          projectId: projectLegacyId,
          scriptId: scriptLegacyId,
          storyboards: payload,
        );
        if (!ctx.mounted) return;
        await _reloadScriptStoryboards(
          token: token,
          scriptLegacyId: scriptLegacyId,
          boardsList: boardsList,
          ctx: ctx,
          setBoardsState: setBoardsState,
          boardsLoading: actionBusy,
        );
        if (!ctx.mounted) return;
        await _reloadProductionStoryboardSummary(
          token: token,
          projectLegacyId: projectLegacyId,
          scriptLegacyId: scriptLegacyId,
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

  Future<void> _openScriptStoryboardsDialog({
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
  }) async {
    try {
      final boards = await fetchStoryboardsForScript(token, scriptLegacyId);
      if (!mounted) return;
      final boardsList = List<StoryboardRow>.from(boards);
      await showDialog<void>(
        context: context,
        builder: (ctx2) {
          final boardsLoading = <bool>[false];
          final actionBusy = <bool>[false];
          final productionSummaryLoading = <bool>[false];
          final productionSummaryLoaded = <bool>[false];
          final productionSummaryLine = <String?>[null];
          final storyboardTaskLine = <String?>[null];
          return StatefulBuilder(
            builder: (ctx2, setBoardsState) {
              final outline = Theme.of(ctx2).colorScheme.outline;
              final diagnosis = diagnoseStoryboardList(
                boards: boardsList,
                productionSummaryLoaded: productionSummaryLoaded[0],
              );
              return AlertDialog(
                title: Text('分镜 (${boardsList.length})'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        boardsList.isEmpty
                            ? '当前剧本还没有分镜，可直接新增单条或按每行一个提示词批量导入。'
                            : '按剧本维护分镜顺序、提示词与状态；点击条目可进入单条编辑。',
                        style: Theme.of(
                          ctx2,
                        ).textTheme.bodySmall?.copyWith(color: outline),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        productionSummaryLine[0] ?? '制作视图摘要尚未加载',
                        style: Theme.of(
                          ctx2,
                        ).textTheme.bodySmall?.copyWith(color: outline),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: outline.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diagnosis.summary,
                              style: Theme.of(ctx2).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '推荐动作：${describeStoryboardListRecommendedAction(diagnosis.recommendedAction)}',
                              style: Theme.of(
                                ctx2,
                              ).textTheme.bodySmall?.copyWith(color: outline),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diagnosis.detail,
                              style: Theme.of(ctx2).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (storyboardTaskLine[0] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          storyboardTaskLine[0]!,
                          style: Theme.of(ctx2).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: actionBusy[0] || boardsLoading[0]
                                  ? null
                                  : () => _openAddStoryboardDialog(
                                      ctx: ctx2,
                                      setBoardsState: setBoardsState,
                                      token: token,
                                      projectLegacyId: projectLegacyId,
                                      scriptLegacyId: scriptLegacyId,
                                      boardsList: boardsList,
                                      actionBusy: actionBusy,
                                      storyboardTaskLine: storyboardTaskLine,
                                      productionSummaryLine:
                                          productionSummaryLine,
                                      productionSummaryLoaded:
                                          productionSummaryLoaded,
                                    ),
                              child: Text(actionBusy[0] ? '处理中…' : '新增分镜'),
                            ),
                            TextButton(
                              onPressed: actionBusy[0] || boardsLoading[0]
                                  ? null
                                  : () => _openBatchAddStoryboardsDialog(
                                      ctx: ctx2,
                                      setBoardsState: setBoardsState,
                                      token: token,
                                      projectLegacyId: projectLegacyId,
                                      scriptLegacyId: scriptLegacyId,
                                      boardsList: boardsList,
                                      actionBusy: actionBusy,
                                      storyboardTaskLine: storyboardTaskLine,
                                      productionSummaryLine:
                                          productionSummaryLine,
                                      productionSummaryLoaded:
                                          productionSummaryLoaded,
                                    ),
                              child: const Text('批量新增分镜'),
                            ),
                            TextButton(
                              onPressed: actionBusy[0] || boardsLoading[0]
                                  ? null
                                  : () => _reloadScriptStoryboards(
                                      token: token,
                                      scriptLegacyId: scriptLegacyId,
                                      boardsList: boardsList,
                                      ctx: ctx2,
                                      setBoardsState: setBoardsState,
                                      boardsLoading: boardsLoading,
                                    ),
                              child: Text(boardsLoading[0] ? '刷新中…' : '刷新列表'),
                            ),
                            TextButton(
                              onPressed: actionBusy[0] || boardsLoading[0]
                                  ? null
                                  : () async {
                                      await _openStoryboardBatchWorkbenchDialog(
                                        ctx: ctx2,
                                        token: token,
                                        projectLegacyId: projectLegacyId,
                                        scriptLegacyId: scriptLegacyId,
                                        boardsList: boardsList,
                                        setBoardsState: setBoardsState,
                                        actionBusy: actionBusy,
                                      );
                                      if (!ctx2.mounted) return;
                                      await _reloadScriptStoryboards(
                                        token: token,
                                        scriptLegacyId: scriptLegacyId,
                                        boardsList: boardsList,
                                        ctx: ctx2,
                                        setBoardsState: setBoardsState,
                                        boardsLoading: boardsLoading,
                                      );
                                      if (!ctx2.mounted) return;
                                      await _reloadProductionStoryboardSummary(
                                        token: token,
                                        projectLegacyId: projectLegacyId,
                                        scriptLegacyId: scriptLegacyId,
                                        productionSummaryLine:
                                            productionSummaryLine,
                                        productionSummaryLoaded:
                                            productionSummaryLoaded,
                                        productionSummaryLoading:
                                            productionSummaryLoading,
                                        setBoardsState: setBoardsState,
                                      );
                                    },
                              child: const Text('分镜出图工作台'),
                            ),
                            TextButton(
                              onPressed:
                                  actionBusy[0] || productionSummaryLoading[0]
                                  ? null
                                  : () => _reloadProductionStoryboardSummary(
                                      token: token,
                                      projectLegacyId: projectLegacyId,
                                      scriptLegacyId: scriptLegacyId,
                                      productionSummaryLine:
                                          productionSummaryLine,
                                      productionSummaryLoaded:
                                          productionSummaryLoaded,
                                      productionSummaryLoading:
                                          productionSummaryLoading,
                                      setBoardsState: setBoardsState,
                                    ),
                              child: Text(
                                productionSummaryLoading[0]
                                    ? '读取制作视图…'
                                    : '刷新制作视图',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 320,
                        child: boardsList.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无分镜',
                                  style: Theme.of(ctx2).textTheme.bodyMedium
                                      ?.copyWith(color: outline),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: boardsList.length,
                                itemBuilder: (_, i) {
                                  final b = boardsList[i];
                                  final parts = <String>[
                                    '序号 ${b.sbIndex ?? i + 1}',
                                    if ((b.state ?? '').trim().isNotEmpty)
                                      '状态 ${b.state}',
                                    if ((b.duration ?? '').trim().isNotEmpty)
                                      '时长 ${b.duration}',
                                  ];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('#${b.legacyId}'),
                                    subtitle: Text(
                                      [
                                        if ((b.prompt ?? '').trim().isNotEmpty)
                                          b.prompt!.trim(),
                                        if (parts.isNotEmpty) parts.join(' · '),
                                      ].join('\n'),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    onTap: actionBusy[0] || boardsLoading[0]
                                        ? null
                                        : () async {
                                            await _openStoryboardEditor(
                                              token,
                                              b.legacyId,
                                              projectLegacyId: projectLegacyId,
                                              scriptLegacyId: scriptLegacyId,
                                              onStoryboardTreeMutated: () async {
                                                await _reloadScriptStoryboards(
                                                  token: token,
                                                  scriptLegacyId:
                                                      scriptLegacyId,
                                                  boardsList: boardsList,
                                                  ctx: ctx2,
                                                  setBoardsState:
                                                      setBoardsState,
                                                  boardsLoading: boardsLoading,
                                                );
                                                if (!ctx2.mounted) return;
                                                await _reloadProductionStoryboardSummary(
                                                  token: token,
                                                  projectLegacyId:
                                                      projectLegacyId,
                                                  scriptLegacyId:
                                                      scriptLegacyId,
                                                  productionSummaryLine:
                                                      productionSummaryLine,
                                                  productionSummaryLoaded:
                                                      productionSummaryLoaded,
                                                  productionSummaryLoading:
                                                      productionSummaryLoading,
                                                  setBoardsState:
                                                      setBoardsState,
                                                );
                                              },
                                            );
                                          },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
