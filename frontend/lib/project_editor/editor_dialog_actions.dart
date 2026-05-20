part of '../../home_page.dart';

extension _HomePageProjectEditorDialogActions on _HomePageState {
  List<Widget> _buildProjectEditorDialogActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required TextEditingController premiseCtrl,
    required TextEditingController audienceCtrl,
    required TextEditingController toneCtrl,
    required TextEditingController hookCtrl,
    required TextEditingController visualCtrl,
    required TextEditingController textModelCtrl,
    required TextEditingController multimodalModelCtrl,
    required TextEditingController imageModelCtrl,
    required TextEditingController videoModelCtrl,
    required TextEditingController voiceModelCtrl,
    required TextEditingController voiceProfileCtrl,
    required TextEditingController brandNameCtrl,
    required TextEditingController brandPromiseCtrl,
    required TextEditingController visualMotifsCtrl,
    required TextEditingController forbiddenCtrl,
    required TextEditingController continuityCtrl,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return [
      TextButton(
        onPressed: dialogState.saving[0] ? null : () => Navigator.of(ctx).pop(),
        child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
      ),
      TextButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                final ok = await showStudioDialog<bool>(
                  context: ctx,
                  builder: (c) {
                    final dlgL10n = resolveAppLocalizationsForErrors(c);
                    return StudioAlertDialog(
                      title: Text(dlgL10n.projectEditorDeleteProjectTitle),
                      content: Text(
                        dlgL10n.projectEditorDeleteProjectBody(p.numericId),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: Text(dlgL10n.storyboardEditorDialogCancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: Text(
                            dlgL10n.storyboardEditorDialogConfirmDelete,
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (ok != true || !ctx.mounted) return;
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  await deleteProjectByProjectId(token, p.id);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _projectsController.loadProjects();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorDeleteProjectSnackbar),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(describeUserVisibleApiErrorResolved(ctx, e)),
                      ),
                    );
                  }
                }
              },
        child: Text(l10n.projectEditorDeleteProjectButton),
      ),
      FilledButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  final currentProject = dialogState;
                  final selectedArtStylePack =
                      currentProject.selectedArtStylePackRef[0];
                  final selectedStoryStylePack =
                      currentProject.selectedStoryStylePackRef[0];
                  List<String> splitLines(String raw) => raw
                      .split('\n')
                      .map((line) => line.trim())
                      .where((line) => line.isNotEmpty)
                      .toList(growable: false);
                  await updateProjectByProjectId(token, p.id, {
                    'name': nameCtrl.text.isEmpty ? null : nameCtrl.text,
                    'intro': introCtrl.text.isEmpty ? null : introCtrl.text,
                    'textModel': textModelCtrl.text.isEmpty
                        ? null
                        : textModelCtrl.text,
                    'multimodalModel': multimodalModelCtrl.text.isEmpty
                        ? null
                        : multimodalModelCtrl.text,
                    'imageModel': imageModelCtrl.text.isEmpty
                        ? null
                        : imageModelCtrl.text,
                    'videoModel': videoModelCtrl.text.isEmpty
                        ? null
                        : videoModelCtrl.text,
                    'voiceModel': voiceModelCtrl.text.isEmpty
                        ? null
                        : voiceModelCtrl.text,
                    'voiceProfile': voiceProfileCtrl.text.isEmpty
                        ? null
                        : voiceProfileCtrl.text,
                    'projectBrief': ProjectBriefDraft(
                      premise: premiseCtrl.text,
                      targetAudience: audienceCtrl.text,
                      emotionalTone: toneCtrl.text,
                      coreHook: hookCtrl.text,
                      visualDirection: visualCtrl.text,
                    ).toJsonOrNull(),
                    'brandBible': BrandBibleDraft(
                      brandName: brandNameCtrl.text,
                      brandPromise: brandPromiseCtrl.text,
                      visualMotifs: splitLines(visualMotifsCtrl.text),
                      forbiddenElements: splitLines(forbiddenCtrl.text),
                      continuityRules: splitLines(continuityCtrl.text),
                    ).toJsonOrNull(),
                  });
                  final artPackToSave = _nullableNormalizedArtPack(
                    selectedArtStylePack,
                  );
                  final storyPackToSave = _nullableNormalizedStoryPack(
                    selectedStoryStylePack,
                  );
                  if (!artStylePackPathsMatch(artPackToSave, p.artStylePack) ||
                      !storyStylePackPathsMatch(
                        storyPackToSave,
                        p.storyStylePack,
                      )) {
                    await patchProjectStyleConfigByProjectId(
                      token,
                      p.id,
                      artStylePack: artPackToSave,
                      storyStylePack: storyPackToSave,
                    );
                  }
                  final stepPatch = dialogState.stepModelsPatchRef[0];
                  if (stepPatch.isNotEmpty) {
                    await patchProjectModelRoutingV1(
                      token,
                      p.id,
                      steps: stepPatch,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _projectsController.loadProjects();
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(describeUserVisibleApiErrorResolved(ctx, e)),
                      ),
                    );
                  }
                }
              },
        child: Text(
          dialogState.saving[0]
              ? l10n.projectEditorSavingEllipsis
              : l10n.projectEditorSavePatch,
        ),
      ),
    ];
  }
}
