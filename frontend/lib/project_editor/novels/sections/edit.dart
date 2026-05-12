part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchEditSection on _HomePageState {
  Widget _buildNovelWorkbenchEditSection({
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
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required TextEditingController patchIntakeStatusCtrl,
    required TextEditingController patchIntakeSourceUrlCtrl,
    required TextEditingController patchIntakeNoteCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsWorkbenchEditSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: selectedNovelIdCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditNumericIdLabel,
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
                      action: () => _readNovelWorkbenchChapter(
                        l10n: l10n,
                        token: token,
                        project: project,
                        selectedNovelIdCtrl: selectedNovelIdCtrl,
                        patchChapterCtrl: patchChapterCtrl,
                        patchBodyCtrl: patchBodyCtrl,
                        patchIntakeStatusCtrl: patchIntakeStatusCtrl,
                        patchIntakeSourceUrlCtrl: patchIntakeSourceUrlCtrl,
                        patchIntakeNoteCtrl: patchIntakeNoteCtrl,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: Text(l10n.projectEditorNovelsWorkbenchEditReadButton),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchChapterCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditPatchChapterLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchBodyCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditPatchBodyLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchIntakeStatusCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditIntakeStatusLabel,
            helperText: l10n.projectEditorNovelsWorkbenchEditIntakeStatusHelper,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchIntakeSourceUrlCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditSourceUrlLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patchIntakeNoteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchEditIntakeNoteLabel,
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
                  action: () => _saveNovelWorkbenchChapter(
                    l10n: l10n,
                    token: token,
                    project: project,
                    selectedNovelIdCtrl: selectedNovelIdCtrl,
                    patchChapterCtrl: patchChapterCtrl,
                    patchBodyCtrl: patchBodyCtrl,
                    patchIntakeStatusCtrl: patchIntakeStatusCtrl,
                    patchIntakeSourceUrlCtrl: patchIntakeSourceUrlCtrl,
                    patchIntakeNoteCtrl: patchIntakeNoteCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: Text(l10n.projectEditorNovelsWorkbenchEditSaveButton),
        ),
      ],
    );
  }
}
