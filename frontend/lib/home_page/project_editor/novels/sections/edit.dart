part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchEditSection
    on _HomePageState {
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
}
