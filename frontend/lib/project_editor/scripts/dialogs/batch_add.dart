part of '../../../home_page.dart';

extension _HomePageProjectEditorScriptsBatchAddDialog on _HomePageState {
  /// Opens the batch-add-scripts dialog so the scripts section stays thin.
  Future<void> _openBatchAddScriptsDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    final countCtrl = TextEditingController(text: '3');
    final namePrefixCtrl = TextEditingController(text: l10n.projectEditorScriptsBatchAddDefaultPrefix);
    final scriptDataCtrl = TextEditingController(text: l10n.projectEditorScriptsBatchAddDefaultContent);
    try {
      final confirmed = await showStudioDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StudioAlertDialog(
            title: Text(l10n.projectEditorScriptsBatchAddTitle),
            content: SizedBox(
              width: studioConstrainedDialogWidth(context, maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.projectEditorScriptsBatchAddCountLabel,
                      helperText: l10n.projectEditorScriptsBatchAddCountHelper,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: namePrefixCtrl,
                    decoration: InputDecoration(labelText: l10n.projectEditorScriptsBatchAddNamePrefixLabel),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: scriptDataCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: l10n.projectEditorScriptsBatchAddContentLabel),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l10n.projectEditorScriptsBatchAddCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(dialogCtx),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(l10n.projectEditorScriptsBatchAddCreate),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;

      final count = int.tryParse(countCtrl.text.trim());
      if (count == null || count < 1 || count > 20) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(l10n.projectEditorScriptsBatchAddCountError)));
        return;
      }

      final prefix = namePrefixCtrl.text.trim().isEmpty
          ? l10n.projectEditorScriptsBatchAddDefaultPrefix
          : namePrefixCtrl.text.trim();
      final rows = buildBatchAddScriptItems(
        count: count,
        startingIndex: scriptList.length + 1,
        prefix: prefix,
        scriptData: scriptDataCtrl.text,
      );

      setDialogState(() => saving[0] = true);
      final created = await postScriptsBatchAddByProjectId(
        token,
        projectId: p.id,
        data: rows,
      );
      if (!ctx.mounted) return;
      scriptList.addAll(
        created.scripts.map(
          (s) => ScriptBrief(
            numericId: s.numericId,
            name: s.name,
            extractState: s.extractState,
          ),
        ),
      );
      try {
        statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
      } catch (_) {}
      if (!ctx.mounted) return;
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        l10n,
        selectedIds: scriptList.map((script) => script.numericId),
        scripts: scriptList,
        previewRows: const [],
      );
      setDialogState(() => saving[0] = false);
      setDialogState(() {
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.projectEditorScriptsBatchAddSuccess(created.inserted),
          diagnosis: nextDiagnosis,
        );
      });
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(l10n.projectEditorScriptsBatchAddSuccess(created.inserted))));
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => saving[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
        );
      }
    } finally {
      countCtrl.dispose();
      namePrefixCtrl.dispose();
      scriptDataCtrl.dispose();
    }
  }
}
