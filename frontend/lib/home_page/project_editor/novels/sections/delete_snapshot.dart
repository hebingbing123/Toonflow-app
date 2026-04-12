part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchDeleteSnapshotSection
    on _HomePageState {
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
