import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchDeleteSnapshotSection
    on _HomePageState {
  Widget _buildNovelWorkbenchDeleteSection({
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
    required TextEditingController deleteNovelIdCtrl,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsWorkbenchDeleteSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: deleteNovelIdCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchDeleteNumericIdLabel,
          ),
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
                    l10n: l10n,
                    token: token,
                    project: project,
                    deleteNovelIdCtrl: deleteNovelIdCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: Text(l10n.projectEditorNovelsWorkbenchDeleteButton),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: generateIdsCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchDeleteGenerateIdsLabel,
            helperText: l10n.projectEditorNovelsWorkbenchDeleteGenerateIdsHelper,
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
                    l10n: l10n,
                    token: token,
                    project: project,
                    generateIdsCtrl: generateIdsCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: Text(l10n.projectEditorNovelsWorkbenchDeleteGenerateEventsButton),
        ),
      ],
    );
  }

  Widget _buildNovelWorkbenchSnapshotSection({
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
    required TextEditingController numericIdsCtrl,
    required TextEditingController batchDeleteIdsCtrl,
    required TextEditingController batchAdmissionIdsCtrl,
    required TextEditingController batchAdmissionStatusCtrl,
    required TextEditingController batchAdmissionNoteCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsWorkbenchSnapshotSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: numericIdsCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchSnapshotEventStateIdsLabel,
            helperText:
                l10n.projectEditorNovelsWorkbenchSnapshotEventStateIdsHelper,
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
                        l10n: l10n,
                        token: token,
                        project: project,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: Text(l10n.projectEditorNovelsWorkbenchSnapshotReadNovelDataButton),
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
                        l10n: l10n,
                        token: token,
                        project: project,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: Text(
                l10n.projectEditorNovelsWorkbenchSnapshotReadNovelIndexButton,
              ),
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
                        l10n: l10n,
                        token: token,
                        project: project,
                        numericIdsCtrl: numericIdsCtrl,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: Text(
                l10n.projectEditorNovelsWorkbenchSnapshotReadEventStateButton,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: batchDeleteIdsCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsLabel,
            helperText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsHelper,
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
                    l10n: l10n,
                    token: token,
                    project: project,
                    batchDeleteIdsCtrl: batchDeleteIdsCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: Text(l10n.projectEditorNovelsWorkbenchSnapshotBatchDeleteButton),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: batchAdmissionIdsCtrl,
          decoration: InputDecoration(
            labelText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsLabel,
            helperText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsHelper,
          ),
        ),
        const SizedBox(height: 8),
        StudioDropdownButtonFormField<String>(
          initialValue: batchAdmissionStatusCtrl.text.isEmpty
              ? 'pending_review'
              : batchAdmissionStatusCtrl.text,
          decoration: InputDecoration(
            labelText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionStatusLabel,
          ),
          items: [
            DropdownMenuItem(
              value: 'draft',
              child: Text(l10n.projectEditorNovelsIntakeStatusValueDraft),
            ),
            DropdownMenuItem(
              value: 'pending_review',
              child: Text(l10n.projectEditorNovelsIntakeStatusValuePendingReview),
            ),
            DropdownMenuItem(
              value: 'admitted',
              child: Text(l10n.projectEditorNovelsIntakeStatusValueAdmitted),
            ),
            DropdownMenuItem(
              value: 'rejected',
              child: Text(l10n.projectEditorNovelsIntakeStatusValueRejected),
            ),
          ],
          onChanged: (value) {
            batchAdmissionStatusCtrl.text = value ?? 'pending_review';
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: batchAdmissionNoteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteLabel,
            helperText:
                l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteHelper,
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
                  action: () => _batchUpdateNovelWorkbenchAdmission(
                    l10n: l10n,
                    token: token,
                    project: project,
                    batchAdmissionIdsCtrl: batchAdmissionIdsCtrl,
                    batchAdmissionStatusCtrl: batchAdmissionStatusCtrl,
                    batchAdmissionNoteCtrl: batchAdmissionNoteCtrl,
                    refreshWorkbench: refreshWorkbench,
                    setLocalState: setLocalState,
                    applyInfoLine: updateInfoLine,
                  ),
                ),
          child: Text(
            l10n.projectEditorNovelsWorkbenchSnapshotBatchAdmissionButton,
          ),
        ),
      ],
    );
  }
}
