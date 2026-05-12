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
    required TextEditingController brandNameCtrl,
    required TextEditingController brandPromiseCtrl,
    required TextEditingController visualMotifsCtrl,
    required TextEditingController forbiddenCtrl,
    required TextEditingController continuityCtrl,
  }) {
    return [
      TextButton(
        onPressed: dialogState.saving[0] ? null : () => Navigator.of(ctx).pop(),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete project?'),
                    content: Text(
                      'Deletes project #${p.numericId}, related scripts/storyboards (DB cascade), and clears agent memory for this project.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
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
                    const SnackBar(content: Text('Project deleted')),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: const Text('DELETE'),
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
                  if (selectedArtStylePack != p.artStylePack ||
                      selectedStoryStylePack != p.storyStylePack) {
                    await patchProjectStyleConfigByProjectId(
                      token,
                      p.id,
                      artStylePack: selectedArtStylePack,
                      storyStylePack: selectedStoryStylePack,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _projectsController.loadProjects();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: Text(dialogState.saving[0] ? 'Saving…' : 'Save (PATCH)'),
      ),
    ];
  }
}
