part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchCreateSection
    on _HomePageState {
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
}
