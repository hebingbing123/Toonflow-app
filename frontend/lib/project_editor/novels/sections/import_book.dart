part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchImportSection on _HomePageState {
  Widget _buildNovelWorkbenchImportSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required List<ParsedNovelChapter> importPreviewRows,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(String value) updateInfoLine,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importBatchSizeCtrl,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('整本导入', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: importRawTextCtrl,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: '粘贴整本或多章节正文',
            helperText: '支持按“第十二章 / 第3回 / 第五集”等标题自动切章。',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: importBatchSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每批导入条数'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () {
                      final rows = _parseNovelImportPreview(
                        importRawTextCtrl.text,
                      );
                      applyImportPreview(
                        rows,
                        rows.isEmpty
                            ? '没有识别到可导入内容。'
                            : '已预解析 ${rows.length} 条章节，先确认标题和顺序再导入。',
                      );
                    },
              child: const Text('预解析整本'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _importNovelWorkbenchChapters(
                        token: token,
                        project: project,
                        chapters: importPreviewRows,
                        batchSize:
                            int.tryParse(importBatchSizeCtrl.text.trim()) ?? 10,
                        refreshWorkbench: refreshWorkbench,
                        setLocalState: setLocalState,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('导入预解析章节'),
            ),
          ],
        ),
        if (importPreviewRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(ctx).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('预解析预览（前 5 条）', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 8),
                ...importPreviewRows
                    .take(5)
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '#${row.chapterIndex} ${row.chapter}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ),
                if (importPreviewRows.length > 5)
                  Text(
                    '其余 ${importPreviewRows.length - 5} 条将在导入时按同样顺序写入。',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
