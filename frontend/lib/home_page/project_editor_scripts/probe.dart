part of '../../home_page.dart';

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
    return [
      TextButton(
        onPressed: scriptProbeBusy[0] || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final stamp = DateTime.now().millisecondsSinceEpoch;
                  final created = await postScriptsBatchAdd(
                    token,
                    projectId: p.legacyId,
                    data: [
                      BatchAddScriptItemV1(
                        scriptName: '[flutter batch probe]$stamp',
                        scriptData: 'probe',
                      ),
                    ],
                  );
                  for (final s in created.scripts) {
                    await deleteScriptByLegacyId(token, s.legacyId);
                  }
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/scripts/batch-add：inserted=${created.inserted}',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: const Text('POST scripts/batch-add'),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final rows = await postScriptsGetScriptApi(token, p.legacyId);
                  if (!ctx.mounted) return;
                  final sample = rows.isEmpty
                      ? '0 条'
                      : rows
                            .take(2)
                            .map(
                              (r) => '#${r.legacyId} rel=${r.relatedAssets.length}',
                            )
                            .join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/scripts/get-script-api：${rows.length} 条 · $sample',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: const Text('POST get-script-api'),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final sid = scriptList.first.legacyId;
                  final row = await fetchScriptByLegacyId(token, sid);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'GET …/scripts/legacy/$sid：${row.name ?? "(null)"}',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(scriptProbeBusy[0] ? 'script…' : 'GET scripts/legacy (首条)'),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final sid = scriptList.first.legacyId;
                  final cur = await fetchScriptByLegacyId(token, sid);
                  final patched = await updateScriptByLegacyId(
                    token,
                    sid,
                    <String, dynamic>{'name': cur.name ?? ''},
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'PATCH …/scripts/legacy/$sid name noop → ${patched.name ?? "(null)"}',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          scriptProbeBusy[0] ? 'script…' : 'PATCH scripts/legacy (name noop)',
        ),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.legacyId).toList();
                  final zip = await exportScriptsZip(token, ids);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/scripts/export：${zip.length} bytes · ${ids.length} legacy id(s)',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(scriptProbeBusy[0] ? 'export…' : 'POST scripts/export (ZIP)'),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.legacyId).toList();
                  final rows = await pollScriptExtractState(token, ids);
                  if (!ctx.mounted) return;
                  final sample = rows.isEmpty
                      ? '（empty：均在提取中或 idle）'
                      : rows
                            .take(3)
                            .map((r) => '#${r.legacyId} state=${r.extractState}')
                            .join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/extract-state/poll：${rows.length} row(s) $sample',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(scriptProbeBusy[0] ? 'poll…' : 'POST extract-state/poll'),
      ),
      TextButton(
        onPressed: scriptProbeBusy[0] || scriptList.isEmpty || saving[0]
            ? null
            : () async {
                setDialogState(() => scriptProbeBusy[0] = true);
                try {
                  final ids = scriptList.map((s) => s.legacyId).toList();
                  final acc = await startScriptAssetExtract(
                    token,
                    projectLegacyId: p.legacyId,
                    scriptLegacyIds: ids,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/extract-assets：${acc.status} — ${acc.message}',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptProbeBusy[0] = false);
                  }
                }
              },
        child: Text(scriptProbeBusy[0] ? 'extract…' : 'POST extract-assets'),
      ),
    ];
  }
}
