// ignore_for_file: unused_element
part of '../../../home_page.dart';

extension _HomePageProjectEditorScriptsProbe on _HomePageState {
  List<Widget> _buildProjectScriptsProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<ScriptBrief> scriptList,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return [
      TextButton(
        onPressed: scriptProbeBusy[0] || saving[0]
            ? null
            : () async {
                final confirmed = await showStudioConfirmDialog(
                  context: ctx,
                  title: 'Run batch add probe?',
                  message:
                      'This probe creates temporary scripts and deletes them immediately after the probe completes. The write/delete flow cannot be undone.',
                  confirmLabel: 'Run probe',
                  cancelLabel: MaterialLocalizations.of(ctx).cancelButtonLabel,
                  destructive: true,
                );
                if (confirmed != true || !ctx.mounted) {
                  return;
                }
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final stamp = DateTime.now().millisecondsSinceEpoch;
                  final created = await postScriptsBatchAddByProjectId(
                    token,
                    projectId: p.id,
                    data: [
                      BatchAddScriptItemV1(
                        scriptName: '[flutter batch probe]$stamp',
                        scriptData: 'probe',
                      ),
                    ],
                  );
                  for (final s in created.scripts) {
                    await deleteScriptByProjectAndNumericId(
                      token,
                      p.id,
                      s.numericId,
                    );
                  }
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsBatchAddProbeResult(
                          created.inserted,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorProbeScriptsButtonBatchAdd),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final rows =
                      await postScriptsGetScriptApiByProjectId(token, p.id);
                  if (!ctx.mounted) return;
                  final sample = rows.isEmpty
                      ? l10n.projectEditorProbeScriptsZeroItems
                      : rows
                            .take(2)
                            .map(
                              (r) => '#${r.numericId} rel=${r.relatedAssets.length}',
                            )
                            .join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsPostGetScriptApi(rows.length, sample, p.id),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorProbeScriptsButtonPostGetScriptApi),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final sid = scriptList.first.numericId;
                  final row = await fetchScriptByProjectAndNumericId(
                    token,
                    p.id,
                    sid,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsGetByNumericResult(
                          sid,
                          row.name ?? '(null)',
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0] ? l10n.projectEditorProbeScriptsLoading : l10n.projectEditorProbeScriptsGetFirstScript,
        ),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final sid = scriptList.first.numericId;
                  final cur = await fetchScriptByProjectAndNumericId(
                    token,
                    p.id,
                    sid,
                  );
                  final patched = await updateScriptByProjectAndNumericId(
                    token,
                    p.id,
                    sid,
                    <String, dynamic>{'name': cur.name ?? ''},
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsPatchNameNoopResult(
                          sid,
                          patched.name ?? '(null)',
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0]
              ? l10n.projectEditorProbeScriptsPatchNameNoopBusy
              : l10n.projectEditorProbeScriptsButtonPatchNameNoop,
        ),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.numericId).toList();
                  final zip = await exportScriptsZip(token, ids);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsExportZipResult(
                          zip.length,
                          ids.length,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0]
              ? l10n.projectEditorProbeScriptsExportZipBusy
              : l10n.projectEditorProbeScriptsButtonExportZip,
        ),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.numericId).toList();
                  final rows = await pollScriptExtractState(token, ids);
                  if (!ctx.mounted) return;
                  final sample = rows.isEmpty
                      ? l10n.projectEditorProbeScriptsEmpty
                      : rows
                            .take(3)
                            .map((r) => '#${r.numericId} state=${r.extractState}')
                            .join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsPollExtractResult(
                          rows.length,
                          sample,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0]
              ? l10n.projectEditorProbeScriptsPollExtractBusy
              : l10n.projectEditorProbeScriptsButtonPollExtract,
        ),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.numericId).toList();
                  final acc = await startScriptAssetExtract(
                    token,
                    projectUuid: p.id,
                    scriptNumericIds: ids,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeScriptsExtractAssetsResult(
                          acc.status,
                          acc.message,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0]
              ? l10n.projectEditorProbeScriptsExtractAssetsBusy
              : l10n.projectEditorProbeScriptsButtonExtractAssets,
        ),
      ),
    ];
  }
}
