part of '../../home_page.dart';

extension _HomePageStoryboardEditor on _HomePageState {
  Future<void> _openStoryboardEditor(
    String token,
    int storyNumericId, {
    required String projectId,
    required int scriptNumericId,
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByProjectAndNumericId(
        token,
        projectId,
        storyNumericId,
      );
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showStudioDialog<void>(
        context: context,
        builder: (ctx) {
          final saving = <bool>[false];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final l10n = resolveAppLocalizationsForErrors(ctx);
              final viewportWidth = MediaQuery.sizeOf(ctx).width;
              final dialogWidth = viewportWidth.isFinite
                  ? viewportWidth.clamp(320.0, 720.0)
                  : 720.0;
              return StudioAlertDialog(
                title: Text(l10n.storyboardEditorDialogTitle(row.numericId)),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StoryboardWorkbenchPanel(
                          token: token,
                          projectId: projectId,
                          storyNumericId: storyNumericId,
                          scriptNumericId: scriptNumericId,
                          scriptStoryboard: row,
                          readPromptText: () => promptCtrl.text,
                          readVideoDescriptionText: () => videoCtrl.text,
                          videoDescriptionCtrl: videoCtrl,
                          onStoryboardMutated: onStoryboardTreeMutated,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: promptCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.storyboardEditorPromptLabelClearEmpty,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: stateCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.storyboardEditorStateLabelClearEmpty,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: videoCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText:
                                l10n.storyboardEditorVideoDescLabelClearEmpty,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sbIdxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.storyboardEditorSbIndexLabelClearEmpty,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: sgiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n
                                      .storyboardEditorShouldGenerateImageLabelClearEmpty,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showStudioDialog<bool>(
                              context: ctx,
                              builder: (c) => StudioAlertDialog(
                                title: Text(l10n.storyboardEditorDeleteConfirmTitle),
                                content: Text(
                                  l10n.storyboardEditorDeleteConfirmBody(
                                    row.numericId,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(c).pop(false),
                                    child: Text(l10n.storyboardEditorDialogCancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(c).pop(true),
                                    child: Text(
                                      l10n.storyboardEditorDialogConfirmDelete,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteStoryboardByProjectAndNumericId(
                                token,
                                projectId,
                                storyNumericId,
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.storyboardEditorDeletedSnack),
                                ),
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
                                );
                              }
                            }
                          },
                    child: Text(l10n.storyboardEditorDeleteStoryboard),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? sbIdx;
                            final sbs = sbIdxCtrl.text.trim();
                            if (sbs.isNotEmpty) {
                              sbIdx = int.tryParse(sbs);
                              if (sbIdx == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.storyboardEditorSbIndexMustBeInteger,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            int? sgi;
                            final sgis = sgiCtrl.text.trim();
                            if (sgis.isNotEmpty) {
                              sgi = int.tryParse(sgis);
                              if (sgi == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n
                                            .storyboardEditorShouldGenerateImageMustBeInteger,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByProjectAndNumericId(
                                token,
                                projectId,
                                storyNumericId,
                                {
                                  'prompt': promptCtrl.text.isEmpty
                                      ? null
                                      : promptCtrl.text,
                                  'state': stateCtrl.text.isEmpty
                                      ? null
                                      : stateCtrl.text,
                                  'video_desc': videoCtrl.text.isEmpty
                                      ? null
                                      : videoCtrl.text,
                                  'sb_index': sbs.isEmpty ? null : sbIdx,
                                  'should_generate_image': sgis.isEmpty
                                      ? null
                                      : sgi,
                                },
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
                                );
                              }
                            }
                          },
                    child: Text(
                      saving[0]
                          ? l10n.storyboardEditorSaving
                          : l10n.storyboardEditorSaveChanges,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } finally {
      promptCtrl.dispose();
      stateCtrl.dispose();
      videoCtrl.dispose();
      sbIdxCtrl.dispose();
      sgiCtrl.dispose();
    }
  }
}
