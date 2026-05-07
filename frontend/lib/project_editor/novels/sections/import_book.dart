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
    required TextEditingController importUrlCtrl,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importBatchSizeCtrl,
    required TextEditingController importIntakeStatusCtrl,
    required TextEditingController importIntakeNoteCtrl,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
  }) {
    void updatePreviewRows(
      List<ParsedNovelChapter> rows,
      String message, {
      bool dropEmptyBodies = false,
    }) {
      final normalized = reindexParsedNovelChapters(
        rows,
        dropEmptyBodies: dropEmptyBodies,
      );
      applyImportPreview(normalized, message);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('整本导入', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: importUrlCtrl,
          decoration: const InputDecoration(
            labelText: '抓取 URL',
            helperText: 'client-side crawl：抓页面、抽正文、回填到下方整本导入区。',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: localBusy
                ? null
                : () => _runNovelWorkbenchAction(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    setLocalState: setLocalState,
                    novelsBusy: novelsBusy,
                    setLocalBusy: setLocalBusy,
                    action: () => _crawlNovelSourcePreview(
                      importUrlCtrl: importUrlCtrl,
                      importRawTextCtrl: importRawTextCtrl,
                      applyInfoLine: updateInfoLine,
                      applyImportPreview: applyImportPreview,
                    ),
                  ),
            child: const Text('抓取并预解析'),
          ),
        ),
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
                        intakeSourceUrl: importUrlCtrl.text.trim(),
                        intakeStatus: importIntakeStatusCtrl.text.trim(),
                        intakeNote: importIntakeNoteCtrl.text.trim().isEmpty
                            ? null
                            : importIntakeNoteCtrl.text.trim(),
                        refreshWorkbench: refreshWorkbench,
                        setLocalState: setLocalState,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('导入预解析章节'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: importIntakeStatusCtrl.text.isEmpty
                    ? 'pending_review'
                    : importIntakeStatusCtrl.text,
                decoration: const InputDecoration(labelText: '导入后准入状态'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('draft')),
                  DropdownMenuItem(
                    value: 'pending_review',
                    child: Text('pending_review'),
                  ),
                  DropdownMenuItem(value: 'admitted', child: Text('admitted')),
                  DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                ],
                onChanged: (value) {
                  importIntakeStatusCtrl.text = value ?? 'pending_review';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: importIntakeNoteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '导入备注',
                  helperText: '可写抓取来源、清洗说明、待审原因等',
                ),
              ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '预解析修正区（${importPreviewRows.length} 条）',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: localBusy
                          ? null
                          : () {
                              updatePreviewRows([
                                ...importPreviewRows,
                                ParsedNovelChapter(
                                  chapterIndex: importPreviewRows.length + 1,
                                  chapter:
                                      '补充章节 ${importPreviewRows.length + 1}',
                                  chapterData: '',
                                ),
                              ], '已追加 1 条补充章节，请补全标题和正文后导入。');
                            },
                      child: const Text('补充章节'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...importPreviewRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${row.chapterIndex}',
                                style: Theme.of(ctx).textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: '删除该章节',
                              onPressed: localBusy
                                  ? null
                                  : () {
                                      final updated =
                                          List<ParsedNovelChapter>.from(
                                            importPreviewRows,
                                          )..removeAt(index);
                                      updatePreviewRows(
                                        updated,
                                        '已删除第 ${row.chapterIndex} 条预解析章节。',
                                      );
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: ValueKey(
                            'import-preview-title-${row.chapterIndex}-${row.chapter}',
                          ),
                          initialValue: row.chapter,
                          decoration: const InputDecoration(labelText: '章节标题'),
                          onChanged: (value) {
                            final updated = List<ParsedNovelChapter>.from(
                              importPreviewRows,
                            );
                            updated[index] = row.copyWith(chapter: value);
                            updatePreviewRows(
                              updated,
                              '已更新第 ${row.chapterIndex} 条预解析章节。',
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey(
                            'import-preview-body-${row.chapterIndex}-${row.chapterData.length}',
                          ),
                          initialValue: row.chapterData,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: '章节正文'),
                          onChanged: (value) {
                            final updated = List<ParsedNovelChapter>.from(
                              importPreviewRows,
                            );
                            updated[index] = row.copyWith(chapterData: value);
                            updatePreviewRows(
                              updated,
                              '已更新第 ${row.chapterIndex} 条正文。',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Text(
                  '导入时会自动重新编号；空正文章节会被拦下，需先在这里补全。',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                if (importPreviewRows.length > 12) ...[
                  const SizedBox(height: 4),
                  Text(
                    '当前预览较长，继续向下滚动可逐条修正全部章节。',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
