import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import '../../storyboard_editor/support/diagnosis.dart';

class StoryboardsWorkbenchDialogViewModel {
  const StoryboardsWorkbenchDialogViewModel({
    required this.boardsList,
    required this.diagnosis,
    required this.productionSummaryLine,
    required this.storyboardTaskLine,
    required this.actionBusy,
    required this.boardsLoading,
    required this.productionSummaryLoading,
  });

  final List<StoryboardRow> boardsList;
  final StoryboardListDiagnosis diagnosis;
  final String? productionSummaryLine;
  final String? storyboardTaskLine;
  final bool actionBusy;
  final bool boardsLoading;
  final bool productionSummaryLoading;
}

class StoryboardsWorkbenchDialogViewCallbacks {
  const StoryboardsWorkbenchDialogViewCallbacks({
    required this.onAddStoryboard,
    required this.onBatchAddStoryboards,
    required this.onReloadBoards,
    required this.onOpenBatchWorkbench,
    required this.onReloadProductionSummary,
    required this.onOpenStoryboard,
    required this.onClose,
  });

  final VoidCallback? onAddStoryboard;
  final VoidCallback? onBatchAddStoryboards;
  final VoidCallback? onReloadBoards;
  final VoidCallback? onOpenBatchWorkbench;
  final VoidCallback? onReloadProductionSummary;
  final Future<void> Function(StoryboardRow board) onOpenStoryboard;
  final VoidCallback onClose;
}

class StoryboardsWorkbenchDialogView extends StatelessWidget {
  const StoryboardsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final StoryboardsWorkbenchDialogViewModel model;
  final StoryboardsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: Text('分镜 (${model.boardsList.length})'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                model.boardsList.isEmpty
                    ? '当前剧本还没有分镜，可直接新增单条或按每行一个提示词批量导入。'
                    : '按剧本维护分镜顺序、提示词与状态；点击条目可进入单条编辑。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Text(
                model.productionSummaryLine ?? '制作视图摘要尚未加载',
                style: Theme.of(
                  context,
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
                      model.diagnosis.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '推荐动作：${describeStoryboardListRecommendedAction(model.diagnosis.recommendedAction)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.diagnosis.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (model.storyboardTaskLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.storyboardTaskLine!,
                  style: Theme.of(context).textTheme.bodySmall,
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
                      onPressed: callbacks.onAddStoryboard,
                      child: Text(model.actionBusy ? '处理中…' : '新增分镜'),
                    ),
                    TextButton(
                      onPressed: callbacks.onBatchAddStoryboards,
                      child: const Text('批量新增分镜'),
                    ),
                    TextButton(
                      onPressed: callbacks.onReloadBoards,
                      child: Text(model.boardsLoading ? '刷新中…' : '刷新列表'),
                    ),
                    TextButton(
                      onPressed: callbacks.onOpenBatchWorkbench,
                      child: const Text('分镜出图工作台'),
                    ),
                    TextButton(
                      onPressed: callbacks.onReloadProductionSummary,
                      child: Text(
                        model.productionSummaryLoading ? '读取制作视图…' : '刷新制作视图',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: model.boardsList.isEmpty
                    ? Center(
                        child: Text(
                          '暂无分镜',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: outline),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: model.boardsList.length,
                        itemBuilder: (_, i) {
                          final board = model.boardsList[i];
                          final parts = <String>[
                            '序号 ${board.sbIndex ?? i + 1}',
                            if ((board.state ?? '').trim().isNotEmpty)
                              '状态 ${board.state}',
                            if ((board.duration ?? '').trim().isNotEmpty)
                              '时长 ${board.duration}',
                          ];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('#${board.numericId}'),
                            subtitle: Text(
                              [
                                if ((board.prompt ?? '').trim().isNotEmpty)
                                  board.prompt!.trim(),
                                if (parts.isNotEmpty) parts.join(' · '),
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.edit_outlined, size: 18),
                            onTap: model.actionBusy || model.boardsLoading
                                ? null
                                : () => callbacks.onOpenStoryboard(board),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('Close')),
      ],
    );
  }
}
