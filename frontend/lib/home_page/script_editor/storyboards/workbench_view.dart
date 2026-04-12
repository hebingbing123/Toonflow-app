part of '../../../home_page.dart';

/// 分镜工作台视图，承载摘要、动作条与列表布局。
extension _HomePageScriptEditorStoryboardsView on _HomePageState {
  Widget _buildScriptStoryboardsDialogView({
    required BuildContext ctx,
    required Color outline,
    required List<StoryboardRow> boardsList,
    required StoryboardListDiagnosis diagnosis,
    required String? productionSummaryLine,
    required String? storyboardTaskLine,
    required bool actionBusy,
    required bool boardsLoading,
    required bool productionSummaryLoading,
    required VoidCallback? onAddStoryboard,
    required VoidCallback? onBatchAddStoryboards,
    required VoidCallback? onReloadBoards,
    required VoidCallback? onOpenBatchWorkbench,
    required VoidCallback? onReloadProductionSummary,
    required Future<void> Function(StoryboardRow board) onOpenStoryboard,
    required VoidCallback onClose,
  }) {
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
                ctx,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            const SizedBox(height: 8),
            Text(
              productionSummaryLine ?? '制作视图摘要尚未加载',
              style: Theme.of(
                ctx,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: outline.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis.summary,
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '推荐动作：${describeStoryboardListRecommendedAction(diagnosis.recommendedAction)}',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    diagnosis.detail,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (storyboardTaskLine != null) ...[
              const SizedBox(height: 8),
              Text(
                storyboardTaskLine,
                style: Theme.of(ctx).textTheme.bodySmall,
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
                    onPressed: onAddStoryboard,
                    child: Text(actionBusy ? '处理中…' : '新增分镜'),
                  ),
                  TextButton(
                    onPressed: onBatchAddStoryboards,
                    child: const Text('批量新增分镜'),
                  ),
                  TextButton(
                    onPressed: onReloadBoards,
                    child: Text(boardsLoading ? '刷新中…' : '刷新列表'),
                  ),
                  TextButton(
                    onPressed: onOpenBatchWorkbench,
                    child: const Text('分镜出图工作台'),
                  ),
                  TextButton(
                    onPressed: onReloadProductionSummary,
                    child: Text(
                      productionSummaryLoading ? '读取制作视图…' : '刷新制作视图',
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
                        style: Theme.of(
                          ctx,
                        ).textTheme.bodyMedium?.copyWith(color: outline),
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
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: actionBusy || boardsLoading
                              ? null
                              : () => onOpenStoryboard(b),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('Close'))],
    );
  }
}
