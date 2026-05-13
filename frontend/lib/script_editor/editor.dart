part of '../../home_page.dart';

extension _HomePageScriptEditor on _HomePageState {
  Future<void> _openScriptEditor(
    String token,
    int scriptNumericId, {
    required String projectId,
    Future<void> Function()? onScriptTreeMutated,
  }) async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    try {
      final script = await fetchScriptByProjectAndNumericId(
        token,
        projectId,
        scriptNumericId,
      );
      if (!mounted) return;
      nameCtrl.text = script.name ?? '';
      contentCtrl.text = script.content ?? '';
      stateCtrl.text = script.extractState?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              final viewportWidth = MediaQuery.sizeOf(ctx).width;
              final dialogWidth = viewportWidth.isFinite
                  ? viewportWidth.clamp(320.0, 720.0)
                  : 720.0;
              return AlertDialog(
                title: Text(l10n.scriptEditorDialogTitle(script.numericId)),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScriptWorkbenchPanel(
                          token: token,
                          projectId: projectId,
                          scriptNumericId: scriptNumericId,
                          onExtractStateSynced: (extractState) {
                            stateCtrl.text = extractState?.toString() ?? '';
                          },
                          onOpenEditImageWorkbench: () =>
                              _openScriptEditImageWorkbenchDialog(
                                token: token,
                                projectId: projectId,
                                scriptNumericId: scriptNumericId,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.scriptEditorFieldNameLabelClearIfEmpty,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contentCtrl,
                          minLines: 4,
                          maxLines: 12,
                          decoration: InputDecoration(
                            labelText: l10n.scriptEditorFieldContentLabelClearIfEmpty,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: stateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                l10n.scriptEditorFieldExtractStateLabelClearIfEmpty,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: saving[0]
                                ? null
                                : () => _openScriptStoryboardsDialog(
                                    token: token,
                                    projectId: projectId,
                                    scriptNumericId: scriptNumericId,
                                  ),
                            child: Text(l10n.scriptEditorOpenStoryboards),
                          ),
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
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) {
                                final confirmL10n = AppLocalizations.of(c)!;
                                return AlertDialog(
                                  title: Text(
                                    confirmL10n.scriptEditorDeleteConfirmTitle,
                                  ),
                                  content: Text(
                                    confirmL10n.scriptEditorDeleteConfirmBody(
                                      script.numericId,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(c).pop(false),
                                      child: Text(
                                        confirmL10n
                                            .projectEditorScriptsBatchAddCancel,
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(c).pop(true),
                                      child: Text(
                                        confirmL10n
                                            .scriptEditorDeleteConfirmDelete,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteScriptByProjectAndNumericId(
                                token,
                                projectId,
                                scriptNumericId,
                              );
                              if (!ctx.mounted) return;
                              await onScriptTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context)!
                                        .scriptEditorDeletedSnackBar,
                                  ),
                                ),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                                );
                              }
                            }
                          },
                    child: Text(l10n.scriptEditorDeleteScriptButton),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? extractParsed;
                            final st = stateCtrl.text.trim();
                            if (st.isNotEmpty) {
                              extractParsed = int.tryParse(st);
                              if (extractParsed == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.scriptEditorExtractStateMustBeInteger,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateScriptByProjectAndNumericId(
                                token,
                                projectId,
                                scriptNumericId,
                                {
                                  'name': nameCtrl.text.isEmpty
                                      ? null
                                      : nameCtrl.text,
                                  'content': contentCtrl.text.isEmpty
                                      ? null
                                      : contentCtrl.text,
                                  'extract_state': st.isEmpty
                                      ? null
                                      : extractParsed,
                                },
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                                );
                              }
                            }
                          },
                    child: Text(
                      saving[0]
                          ? l10n.scriptEditorSaveSaving
                          : l10n.scriptEditorSaveChanges,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } finally {
      nameCtrl.dispose();
      contentCtrl.dispose();
      stateCtrl.dispose();
    }
  }
}
