part of '../../../home_page.dart';

extension _HomePageScriptEditorStoryboards on _HomePageState {
  Future<void> _reloadProductionStoryboardSummary({
    required String token,
    required int projectNumericId,
    required int scriptNumericId,
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
        projectId: projectNumericId,
        scriptId: scriptNumericId,
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
    required int projectNumericId,
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
          final storyboardTaskLine = <String?>[null];
          return StatefulBuilder(
            builder: (ctx2, setBoardsState) {
              if (!autoRefreshQueued[0]) {
                autoRefreshQueued[0] = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!ctx2.mounted) return;
                  await _reloadProductionStoryboardSummary(
                    token: token,
                    projectNumericId: projectNumericId,
                    scriptNumericId: scriptNumericId,
                    productionSummaryLine: productionSummaryLine,
                    productionSummaryLoaded: productionSummaryLoaded,
                    productionSummaryLoading: productionSummaryLoading,
                    setBoardsState: setBoardsState,
                  );
                });
              }
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
                                      projectId: projectId,
                                      projectNumericId: projectNumericId,
                                      scriptNumericId: scriptNumericId,
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
                                      projectId: projectId,
                                      projectNumericId: projectNumericId,
                                      scriptNumericId: scriptNumericId,
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
                                      projectId: projectId,
                                      scriptNumericId: scriptNumericId,
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
                                        projectNumericId: projectNumericId,
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
                                        token: token,
                                        projectNumericId: projectNumericId,
                                        scriptNumericId: scriptNumericId,
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
                                      projectNumericId: projectNumericId,
                                      scriptNumericId: scriptNumericId,
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
                                    title: Text('#${b.numericId}'),
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
                                              b.numericId,
                                              projectId: projectId,
                                              projectNumericId: projectNumericId,
                                              scriptNumericId: scriptNumericId,
                                              onStoryboardTreeMutated: () async {
                                                await _reloadScriptStoryboards(
                                                  token: token,
                                                  projectId: projectId,
                                                  scriptNumericId:
                                                      scriptNumericId,
                                                  boardsList: boardsList,
                                                  ctx: ctx2,
                                                  setBoardsState:
                                                      setBoardsState,
                                                  boardsLoading: boardsLoading,
                                                );
                                                if (!ctx2.mounted) return;
                                                await _reloadProductionStoryboardSummary(
                                                  token: token,
                                                  projectNumericId:
                                                      projectNumericId,
                                                  scriptNumericId:
                                                      scriptNumericId,
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
