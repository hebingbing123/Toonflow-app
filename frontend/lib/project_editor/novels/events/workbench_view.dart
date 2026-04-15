import 'package:flutter/material.dart';

import '../../../../../rust_api.dart';

class NovelEventsWorkbenchDialogViewModel {
  const NovelEventsWorkbenchDialogViewModel({
    required this.infoLine,
    required this.previewRows,
    required this.localBusy,
    required this.searchCtrl,
    required this.createNameCtrl,
    required this.createDetailCtrl,
    required this.createChapterIdsCtrl,
    required this.selectedEventIdCtrl,
    required this.patchNameCtrl,
    required this.patchDetailCtrl,
    required this.patchChapterIdsCtrl,
    required this.batchDeleteIdsCtrl,
  });

  final String infoLine;
  final List<NovelEventRow> previewRows;
  final bool localBusy;
  final TextEditingController searchCtrl;
  final TextEditingController createNameCtrl;
  final TextEditingController createDetailCtrl;
  final TextEditingController createChapterIdsCtrl;
  final TextEditingController selectedEventIdCtrl;
  final TextEditingController patchNameCtrl;
  final TextEditingController patchDetailCtrl;
  final TextEditingController patchChapterIdsCtrl;
  final TextEditingController batchDeleteIdsCtrl;
}

class NovelEventsWorkbenchDialogViewCallbacks {
  const NovelEventsWorkbenchDialogViewCallbacks({
    required this.onSearch,
    required this.onRefresh,
    required this.onCreate,
    required this.onSave,
    required this.onDeleteCurrent,
    required this.onBatchDelete,
    required this.onClose,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onSave;
  final VoidCallback? onDeleteCurrent;
  final VoidCallback? onBatchDelete;
  final VoidCallback? onClose;
}

class NovelEventsWorkbenchDialogView extends StatelessWidget {
  const NovelEventsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final NovelEventsWorkbenchDialogViewModel model;
  final NovelEventsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('事件工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.infoLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (model.previewRows.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前事件预览',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ...model.previewRows.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '#${row.numericId} · ${row.name} · 章节索引 ${row.chapterIndexes.join('/')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: model.searchCtrl,
                decoration: const InputDecoration(
                  labelText: '搜索事件关键字',
                  helperText: '同时调用 REST 与 workbench get-events 搜索',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: callbacks.onSearch,
                    child: const Text('搜索事件'),
                  ),
                  OutlinedButton(
                    onPressed: callbacks.onRefresh,
                    child: const Text('刷新列表'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('新增事件', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: model.createNameCtrl,
                decoration: const InputDecoration(labelText: '事件名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '事件描述'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createChapterIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '关联章节 IDs',
                  helperText: '用逗号分隔，按章节 numeric ID 填写',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: callbacks.onCreate,
                child: const Text('新增事件'),
              ),
              const SizedBox(height: 16),
              Text('更新事件', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: model.selectedEventIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '事件 numeric ID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchNameCtrl,
                decoration: const InputDecoration(labelText: '更新后的事件名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '更新后的事件描述'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.patchChapterIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '更新后的章节 IDs',
                  helperText: '按章节 numeric ID 填写；内部会映射为 chapterIds',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: callbacks.onSave,
                child: const Text('保存事件'),
              ),
              const SizedBox(height: 16),
              Text('删除 / 批量删除', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: callbacks.onDeleteCurrent,
                    child: const Text('删除当前事件'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.batchDeleteIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '批量删除事件 IDs',
                  helperText:
                      'POST …/projects/{uuid}/novel-events/batch-delete；用逗号分隔',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: callbacks.onBatchDelete,
                child: const Text('批量删除事件'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}
