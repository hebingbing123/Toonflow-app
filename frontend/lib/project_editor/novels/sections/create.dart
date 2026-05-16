part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchCreateSection
    on _HomePageState {
  Widget _buildNovelWorkbenchCreateSection({
    required AppLocalizations l10n,
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
        Text(
          l10n.projectEditorNovelsWorkbenchCreateSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: createChapterCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchCreateChapterTitleLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: createBodyCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchCreateChapterBodyLabel,
          ),
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
                    updateInfoLine(l10n.projectEditorNovelsActionChapterCreateOk);
                  },
                ),
          child: Text(l10n.projectEditorNovelsWorkbenchCreateSubmit),
        ),
      ],
    );
  }
}
