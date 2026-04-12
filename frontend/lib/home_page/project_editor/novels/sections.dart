part of '../../../home_page.dart';

/// Keeps novels workbench form sections close to the novels domain so the main
/// workbench file can stay focused on dialog orchestration.
extension _HomePageProjectEditorNovelWorkbenchSections on _HomePageState {
  Widget _buildNovelWorkbenchPreviewSection({
    required BuildContext context,
    required List<NovelRow> previewRows,
  }) {
    if (previewRows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
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
          Text('当前章节预览', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ...previewRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '#${row.numericId} · ${row.chapter} · 事件状态 ${row.eventState}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelWorkbenchSearchSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required TextEditingController searchCtrl,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(List<NovelRow> rows, String infoLine) applyResult,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            labelText: '搜索章节关键字',
            helperText: '调用 GET /projects/{project_uuid}/novels?search=',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _searchNovelWorkbenchRows(
                        token: token,
                        project: project,
                        searchCtrl: searchCtrl,
                        applyResult: applyResult,
                      ),
                    ),
              child: const Text('搜索'),
            ),
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => refreshWorkbench(setLocalState),
                    ),
              child: const Text('刷新列表'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNovelWorkbenchCreateSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController createChapterCtrl,
    required TextEditingController createBodyCtrl,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('新增章节', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: createChapterCtrl,
          decoration: const InputDecoration(labelText: '章节标题'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: createBodyCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '章节正文'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: localBusy
              ? null
              : () => _runNovelWorkbenchAction(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  setLocalState: setLocalState,
                  novelsBusy: novelsBusy,
                  setLocalBusy: setLocalBusy,
                  action: () async {
                    await _createNovelWorkbenchChapter(
                      token: token,
                      project: project,
                      createChapterCtrl: createChapterCtrl,
                      createBodyCtrl: createBodyCtrl,
                      selectedNovelIdCtrl: selectedNovelIdCtrl,
                      patchChapterCtrl: patchChapterCtrl,
                      patchBodyCtrl: patchBodyCtrl,
                      refreshWorkbench: refreshWorkbench,
                      setLocalState: setLocalState,
                    );
                    updateInfoLine('已新增章节。');
                  },
                ),
          child: const Text('新增章节'),
        ),
      ],
    );
  }

  Widget _buildNovelWorkbenchEditSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('读取 / 更新章节', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: selectedNovelIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '章节 numeric ID'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _readNovelWorkbenchChapter(
                        token: token,
                        project: project,
                        selectedNovelIdCtrl: selectedNovelIdCtrl,
                        patchChapterCtrl: patchChapterCtrl,
                        patchBodyCtrl: patchBodyCtrl,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('读取章节'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchChapterCtrl,
          decoration: const InputDecoration(labelText: '更新后的章节标题'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchBodyCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '更新后的章节正文'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: localBusy
              ? null
              : () => _runNovelWorkbenchAction(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  setLocalState: setLocalState,
                  novelsBusy: novelsBusy,
                  setLocalBusy: setLocalBusy,
                  action: () => _saveNovelWorkbenchChapter(
                    token: token,
                    project: project,
                    selectedNovelIdCtrl: selectedNovelIdCtrl,
                    patchChapterCtrl: patchChapterCtrl,
                    patchBodyCtrl: patchBodyCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: const Text('保存章节'),
        ),
      ],
    );
  }

  Widget _buildNovelWorkbenchDeleteSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController deleteNovelIdCtrl,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('删除 / 生成事件', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: deleteNovelIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '待删除章节 numeric ID'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: localBusy
              ? null
              : () => _runNovelWorkbenchAction(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  setLocalState: setLocalState,
                  novelsBusy: novelsBusy,
                  setLocalBusy: setLocalBusy,
                  action: () => _deleteNovelWorkbenchChapter(
                    token: token,
                    project: project,
                    deleteNovelIdCtrl: deleteNovelIdCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: const Text('删除章节'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: generateIdsCtrl,
          decoration: const InputDecoration(
            labelText: '生成事件章节 IDs',
            helperText: '用逗号分隔，如 1,2,3',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: localBusy
              ? null
              : () => _runNovelWorkbenchAction(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  setLocalState: setLocalState,
                  novelsBusy: novelsBusy,
                  setLocalBusy: setLocalBusy,
                  action: () => _generateNovelWorkbenchEvents(
                    token: token,
                    project: project,
                    generateIdsCtrl: generateIdsCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: const Text('生成章节事件'),
        ),
      ],
    );
  }

  Widget _buildNovelWorkbenchSnapshotSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController numericIdsCtrl,
    required TextEditingController batchDeleteIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快照 / 批量动作', style: Theme.of(ctx).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: numericIdsCtrl,
          decoration: const InputDecoration(
            labelText: '查询章节 ID（numeric）',
            helperText: '用于 get-novel-event-state；用逗号分隔，如 1,2,3',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _readNovelWorkbenchData(
                        token: token,
                        project: project,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('读取 get-novel-data'),
            ),
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _readNovelWorkbenchIndex(
                        token: token,
                        project: project,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('读取 get-novel-index'),
            ),
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _readNovelWorkbenchEventStates(
                        token: token,
                        project: project,
                        numericIdsCtrl: numericIdsCtrl,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: const Text('读取 event-state'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: batchDeleteIdsCtrl,
          decoration: const InputDecoration(
            labelText: '批量删除章节 IDs',
            helperText: '调用 workbench batch-delete；用逗号分隔，删除后会回刷工作台。',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: localBusy
              ? null
              : () => _runNovelWorkbenchAction(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  setLocalState: setLocalState,
                  novelsBusy: novelsBusy,
                  setLocalBusy: setLocalBusy,
                  action: () => _batchDeleteNovelWorkbenchChapters(
                    token: token,
                    project: project,
                    batchDeleteIdsCtrl: batchDeleteIdsCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: const Text('批量删除章节'),
        ),
      ],
    );
  }
}
