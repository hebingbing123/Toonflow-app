part of '../../../home_page.dart';

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
    void submitCreateOnEnter() {
      if (localBusy) {
        return;
      }
      final controller = studioFocusedTextField(
        FocusManager.instance.primaryFocus?.context,
      )?.controller;
      if (controller == createChapterCtrl) {
        unawaited(
          _runNovelWorkbenchAction(
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
        );
      }
    }

    return StudioFormKeyboardScope(
      onEnterSubmit: localBusy ? null : submitCreateOnEnter,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsWorkbenchCreateSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: createChapterCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchCreateChapterTitleLabel,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: createBodyCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchCreateChapterBodyLabel,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        FilledButton(
          style: studioFormPrimaryButtonStyle(ctx),
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
    ),
    );
  }
}
