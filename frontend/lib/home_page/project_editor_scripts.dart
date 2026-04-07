part of '../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${scriptList.length} script(s)'),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: scriptProbeBusy[0] || saving[0]
                  ? null
                  : () async {
                      setDialogState(() => scriptProbeBusy[0] = true);
                      try {
                        final rows = await postScriptsGetScriptApi(
                          token,
                          p.legacyId,
                        );
                        if (!ctx.mounted) return;
                        final sample = rows.isEmpty
                            ? '0 条'
                            : rows
                                  .take(2)
                                  .map(
                                    (r) =>
                                        '#${r.legacyId} rel=${r.relatedAssets.length}',
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
              child: Text(
                scriptProbeBusy[0] ? 'script…' : 'GET scripts/legacy (首条)',
              ),
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
                scriptProbeBusy[0]
                    ? 'script…'
                    : 'PATCH scripts/legacy (name noop)',
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
              child: Text(
                scriptProbeBusy[0] ? 'export…' : 'POST scripts/export (ZIP)',
              ),
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
                                  .map(
                                    (r) =>
                                        '#${r.legacyId} state=${r.extractState}',
                                  )
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
              child: Text(
                scriptProbeBusy[0] ? 'poll…' : 'POST extract-state/poll',
              ),
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
              child: Text(
                scriptProbeBusy[0] ? 'extract…' : 'POST extract-assets',
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving[0]
                ? null
                : () async {
                    setDialogState(() => saving[0] = true);
                    try {
                      final s = await createScriptUnderProjectLegacy(
                        token,
                        p.legacyId,
                      );
                      if (!ctx.mounted) return;
                      scriptList.add(
                        ScriptBrief(
                          legacyId: s.legacyId,
                          name: s.name,
                          extractState: s.extractState,
                        ),
                      );
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      if (!ctx.mounted) return;
                      setDialogState(() => saving[0] = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('已创建剧本 legacy #${s.legacyId}'),
                        ),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
            child: const Text('POST 空剧本'),
          ),
        ),
        const SizedBox(height: 8),
        ...scriptList.map(
          (s) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${s.legacyId} ${s.name ?? ""}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: saving[0]
                ? null
                : () => _openScriptEditor(
                    token,
                    s.legacyId,
                    onScriptTreeMutated: () async {
                      final d = await fetchProjectByLegacyId(token, p.legacyId);
                      if (!ctx.mounted) return;
                      scriptList
                        ..clear()
                        ..addAll(d.scripts);
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      setDialogState(() {});
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
