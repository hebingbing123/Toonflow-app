part of '../../../../home_page.dart';

/// 事件工作台视图，承载搜索、预览与 CRUD 表单布局。
extension _HomePageProjectEditorNovelEventsWorkbenchView on _HomePageState {
  Widget _buildNovelEventsWorkbenchDialogView({
    required BuildContext dialogCtx,
    required String infoLine,
    required List<NovelEventRow> previewRows,
    required bool localBusy,
    required TextEditingController searchCtrl,
    required TextEditingController createNameCtrl,
    required TextEditingController createDetailCtrl,
    required TextEditingController createChapterIdsCtrl,
    required TextEditingController selectedEventIdCtrl,
    required TextEditingController patchNameCtrl,
    required TextEditingController patchDetailCtrl,
    required TextEditingController patchChapterIdsCtrl,
    required TextEditingController batchDeleteIdsCtrl,
    required VoidCallback? onSearch,
    required VoidCallback? onRefresh,
    required VoidCallback? onCreate,
    required VoidCallback? onSave,
    required VoidCallback? onDeleteCurrent,
    required VoidCallback? onBatchDelete,
    required VoidCallback? onClose,
  }) {
    return AlertDialog(
      title: const Text('事件工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(infoLine, style: Theme.of(dialogCtx).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (previewRows.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(dialogCtx).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前事件预览',
                        style: Theme.of(dialogCtx).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ...previewRows.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '#${row.numericId} · ${row.name} · 章节索引 ${row.chapterIndexes.join('/')}',
                            style: Theme.of(dialogCtx).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
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
                    onPressed: onSearch,
                    child: const Text('搜索事件'),
                  ),
                  OutlinedButton(
                    onPressed: onRefresh,
                    child: const Text('刷新列表'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('新增事件', style: Theme.of(dialogCtx).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: createNameCtrl,
                decoration: const InputDecoration(labelText: '事件名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '事件描述'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createChapterIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '关联章节 IDs',
                  helperText: '用逗号分隔，按章节 numeric ID 填写',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: onCreate, child: const Text('新增事件')),
              const SizedBox(height: 16),
              Text('更新事件', style: Theme.of(dialogCtx).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: selectedEventIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '事件 numeric ID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: patchNameCtrl,
                decoration: const InputDecoration(labelText: '更新后的事件名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: patchDetailCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '更新后的事件描述'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: patchChapterIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '更新后的章节 IDs',
                  helperText: '按章节 numeric ID 填写；内部会映射为 chapterIds',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onSave, child: const Text('保存事件')),
              const SizedBox(height: 16),
              Text(
                '删除 / 批量删除',
                style: Theme.of(dialogCtx).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onDeleteCurrent,
                    child: const Text('删除当前事件'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchDeleteIdsCtrl,
                decoration: const InputDecoration(
                  labelText: '批量删除事件 IDs',
                  helperText:
                      'POST …/projects/{uuid}/novel-events/batch-delete；用逗号分隔',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onBatchDelete,
                child: const Text('批量删除事件'),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('关闭'))],
    );
  }
}
