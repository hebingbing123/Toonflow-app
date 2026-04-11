part of '../../../home_page.dart';

extension _HomePageProjectEditorScriptsWorkbench on _HomePageState {
  Future<void> _openProjectScriptsWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) async {
    final filterCtrl = TextEditingController();
    final selectedIdsCtrl = TextEditingController(
      text: encodeLegacyIdSelection(
        scriptList.map((script) => script.legacyId),
      ),
    );
    final groupSizeCtrl = TextEditingController(text: '3');
    final addCountCtrl = TextEditingController(text: '3');
    final addPrefixCtrl = TextEditingController(text: '新剧本');
    final addBodyCtrl = TextEditingController(text: '剧情梗概待补充。');

    var localBusy = false;
    var infoLine = scriptList.isEmpty
        ? '当前项目还没有剧本。'
        : '当前已载入 ${scriptList.length} 条剧本，可筛选后批量执行。';
    var previewRows = <LegacyScriptsGetScriptApiItem>[];

    Future<void> reloadScriptsAndStats(StateSetter setLocalState) async {
      final detail = await fetchProjectByProjectId(token, p.id);
      scriptList
        ..clear()
        ..addAll(detail.scripts);
      try {
        statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
      } catch (_) {}
      setLocalState(() {
        infoLine = scriptList.isEmpty
            ? '刷新完成，当前没有剧本。'
            : '刷新完成，共 ${scriptList.length} 条剧本。';
        if (previewRows.isEmpty) {
          selectedIdsCtrl.text = encodeLegacyIdSelection(
            scriptList.map((script) => script.legacyId),
          );
        }
      });
      setDialogState(() {});
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setLocalState) {
              Future<void> runAction(Future<void> Function() action) async {
                setLocalState(() => localBusy = true);
                setDialogState(() => scriptTaskBusy[0] = true);
                try {
                  await action();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => scriptTaskBusy[0] = false);
                  }
                  setLocalState(() => localBusy = false);
                }
              }

              final previewOrLocalIds = previewRows.isNotEmpty
                  ? previewRows.map((row) => row.legacyId)
                  : scriptList.map((script) => script.legacyId);
              final selectedIds = parseLegacyIdSelection(selectedIdsCtrl.text);
              final diagnosis = diagnoseScriptBatchWorkbench(
                selectedIds: selectedIds,
                scripts: scriptList,
                previewRows: previewRows,
              );
              Future<void> Function()? recommendedAction;
              String recommendedActionLabel;
              switch (diagnosis.recommendedAction) {
                case ScriptBatchWorkbenchRecommendedAction.syncContext:
                  recommendedAction = () async {
                    final rows = await postScriptsGetScriptApiByProjectId(
                      token,
                      p.id,
                      name: filterCtrl.text.trim(),
                    );
                    setLocalState(() {
                      previewRows = rows;
                      infoLine = rows.isEmpty
                          ? '上下文读取完成，但没有匹配剧本。'
                          : '已读取 ${rows.length} 条剧本上下文。';
                      selectedIdsCtrl.text = encodeLegacyIdSelection(
                        rows.map((row) => row.legacyId),
                      );
                    });
                  };
                  recommendedActionLabel =
                      describeScriptBatchWorkbenchRecommendedAction(
                        diagnosis.recommendedAction,
                      );
                case ScriptBatchWorkbenchRecommendedAction.pollSelected:
                  recommendedAction = selectedIds.isEmpty
                      ? null
                      : () async {
                          final rows = await pollScriptExtractState(
                            token,
                            selectedIds,
                          );
                          final synced = syncScriptExtractStates(
                            scriptList,
                            rows,
                          );
                          final syncedPreviewRows =
                              syncScriptPreviewExtractStates(previewRows, rows);
                          scriptList
                            ..clear()
                            ..addAll(synced);
                          previewRows = syncedPreviewRows;
                          final sample = rows.isEmpty
                              ? '当前均为 idle 或已完成'
                              : rows
                                    .take(3)
                                    .map(
                                      (row) =>
                                          '#${row.legacyId}:${row.extractState ?? 0}',
                                    )
                                    .join(' · ');
                          final nextDiagnosis = diagnoseScriptBatchWorkbench(
                            selectedIds: selectedIds,
                            scripts: scriptList,
                            previewRows: previewRows,
                          );
                          setLocalState(() {
                            scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                              actionSummary:
                                  '已轮询 ${selectedIds.length} 条剧本提取状态：$sample',
                              diagnosis: nextDiagnosis,
                            );
                          });
                          setDialogState(() {});
                        };
                  recommendedActionLabel =
                      describeScriptBatchWorkbenchRecommendedAction(
                        diagnosis.recommendedAction,
                      );
                case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
                  recommendedAction = selectedIds.isEmpty
                      ? null
                      : () async {
                          final groupSize = int.tryParse(
                            groupSizeCtrl.text.trim(),
                          );
                          final accepted = await startScriptAssetExtract(
                            token,
                            projectNumericId: p.legacyId,
                            scriptNumericIds: selectedIds,
                            groupSize: groupSize,
                          );
                          final rows = await pollScriptExtractState(
                            token,
                            selectedIds,
                          );
                          final synced = syncScriptExtractStates(
                            scriptList,
                            rows,
                          );
                          final syncedPreviewRows =
                              syncScriptPreviewExtractStates(previewRows, rows);
                          scriptList
                            ..clear()
                            ..addAll(synced);
                          previewRows = syncedPreviewRows;
                          final nextDiagnosis = diagnoseScriptBatchWorkbench(
                            selectedIds: selectedIds,
                            scripts: scriptList,
                            previewRows: previewRows,
                          );
                          setLocalState(() {
                            scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                              actionSummary:
                                  '已提交 ${selectedIds.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
                              diagnosis: nextDiagnosis,
                            );
                          });
                          setDialogState(() {});
                        };
                  recommendedActionLabel =
                      describeScriptBatchWorkbenchRecommendedAction(
                        diagnosis.recommendedAction,
                      );
                case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
                  recommendedAction = selectedIds.isEmpty
                      ? null
                      : () async {
                          final zip = await exportScriptsZip(
                            token,
                            selectedIds,
                          );
                          final nextDiagnosis = diagnoseScriptBatchWorkbench(
                            selectedIds: selectedIds,
                            scripts: scriptList,
                            previewRows: previewRows,
                          );
                          setLocalState(() {
                            scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                              actionSummary:
                                  '已导出 ${selectedIds.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
                              diagnosis: nextDiagnosis,
                            );
                          });
                          setDialogState(() {});
                        };
                  recommendedActionLabel =
                      describeScriptBatchWorkbenchRecommendedAction(
                        diagnosis.recommendedAction,
                      );
              }

              return AlertDialog(
                title: const Text('剧本批量工作台'),
                content: SizedBox(
                  width: 820,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          infoLine,
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: filterCtrl,
                          decoration: const InputDecoration(
                            labelText: '剧本名称筛选',
                            helperText:
                                '读取 POST …/projects/{id}/scripts/get-script-api 时按名称过滤，可留空读取全量上下文。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final rows =
                                          await postScriptsGetScriptApiByProjectId(
                                            token,
                                            p.id,
                                            name: filterCtrl.text.trim(),
                                          );
                                      setLocalState(() {
                                        previewRows = rows;
                                        infoLine = rows.isEmpty
                                            ? '上下文读取完成，但没有匹配剧本。'
                                            : '已读取 ${rows.length} 条剧本上下文。';
                                        selectedIdsCtrl.text =
                                            encodeLegacyIdSelection(
                                              rows.map((row) => row.legacyId),
                                            );
                                      });
                                    }),
                              child: const Text('读取剧本上下文'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () {
                                      setLocalState(() {
                                        selectedIdsCtrl.text =
                                            encodeLegacyIdSelection(
                                              previewOrLocalIds,
                                            );
                                      });
                                    },
                              child: Text(
                                previewRows.isNotEmpty ? '使用当前预览' : '使用全部剧本',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      await reloadScriptsAndStats(
                                        setLocalState,
                                      );
                                    }),
                              child: const Text('刷新项目剧本'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: selectedIdsCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '目标剧本 legacy id',
                            helperText: '支持逗号、空格或换行分隔；批量导出、轮询和素材抽取都使用这里的列表。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogCtx)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diagnosis.summary,
                                style: Theme.of(dialogCtx).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diagnosis.detail,
                                style: Theme.of(dialogCtx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        dialogCtx,
                                      ).colorScheme.outline,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed:
                                    localBusy || recommendedAction == null
                                    ? null
                                    : () => runAction(recommendedAction!),
                                child: Text(recommendedActionLabel),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: groupSizeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '素材抽取 group size',
                            helperText: '留空则沿用后端默认分组；设置后用于 extract-assets。',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final selected = parseLegacyIdSelection(
                                        selectedIdsCtrl.text,
                                      );
                                      if (selected.isEmpty) {
                                        throw StateError('请先填写至少一个剧本 id');
                                      }
                                      final zip = await exportScriptsZip(
                                        token,
                                        selected,
                                      );
                                      setLocalState(() {
                                        final nextDiagnosis =
                                            diagnoseScriptBatchWorkbench(
                                              selectedIds: selected,
                                              scripts: scriptList,
                                              previewRows: previewRows,
                                            );
                                        scriptTaskLine[0] =
                                            buildScriptBatchWorkbenchFollowUp(
                                              actionSummary:
                                                  '已导出 ${selected.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
                                              diagnosis: nextDiagnosis,
                                            );
                                      });
                                      setDialogState(() {});
                                    }),
                              child: const Text('导出所选剧本'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final selected = parseLegacyIdSelection(
                                        selectedIdsCtrl.text,
                                      );
                                      if (selected.isEmpty) {
                                        throw StateError('请先填写至少一个剧本 id');
                                      }
                                      final rows = await pollScriptExtractState(
                                        token,
                                        selected,
                                      );
                                      final synced = syncScriptExtractStates(
                                        scriptList,
                                        rows,
                                      );
                                      final syncedPreviewRows =
                                          syncScriptPreviewExtractStates(
                                            previewRows,
                                            rows,
                                          );
                                      scriptList
                                        ..clear()
                                        ..addAll(synced);
                                      previewRows = syncedPreviewRows;
                                      final sample = rows.isEmpty
                                          ? '当前均为 idle 或已完成'
                                          : rows
                                                .take(3)
                                                .map(
                                                  (row) =>
                                                      '#${row.legacyId}:${row.extractState ?? 0}',
                                                )
                                                .join(' · ');
                                      setLocalState(() {
                                        final nextDiagnosis =
                                            diagnoseScriptBatchWorkbench(
                                              selectedIds: selected,
                                              scripts: scriptList,
                                              previewRows: previewRows,
                                            );
                                        scriptTaskLine[0] =
                                            buildScriptBatchWorkbenchFollowUp(
                                              actionSummary:
                                                  '已轮询 ${selected.length} 条剧本提取状态：$sample',
                                              diagnosis: nextDiagnosis,
                                            );
                                      });
                                      setDialogState(() {});
                                    }),
                              child: const Text('轮询所选状态'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final selected = parseLegacyIdSelection(
                                        selectedIdsCtrl.text,
                                      );
                                      if (selected.isEmpty) {
                                        throw StateError('请先填写至少一个剧本 id');
                                      }
                                      final groupSize = int.tryParse(
                                        groupSizeCtrl.text.trim(),
                                      );
                                      final accepted =
                                          await startScriptAssetExtract(
                                            token,
                                            projectNumericId: p.legacyId,
                                            scriptNumericIds: selected,
                                            groupSize: groupSize,
                                          );
                                      final rows = await pollScriptExtractState(
                                        token,
                                        selected,
                                      );
                                      final synced = syncScriptExtractStates(
                                        scriptList,
                                        rows,
                                      );
                                      final syncedPreviewRows =
                                          syncScriptPreviewExtractStates(
                                            previewRows,
                                            rows,
                                          );
                                      scriptList
                                        ..clear()
                                        ..addAll(synced);
                                      previewRows = syncedPreviewRows;
                                      setLocalState(() {
                                        final nextDiagnosis =
                                            diagnoseScriptBatchWorkbench(
                                              selectedIds: selected,
                                              scripts: scriptList,
                                              previewRows: previewRows,
                                            );
                                        scriptTaskLine[0] =
                                            buildScriptBatchWorkbenchFollowUp(
                                              actionSummary:
                                                  '已提交 ${selected.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
                                              diagnosis: nextDiagnosis,
                                            );
                                      });
                                      setDialogState(() {});
                                    }),
                              child: const Text('提取所选素材'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '批量新增剧本',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '数量（1-20）',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addPrefixCtrl,
                          decoration: const InputDecoration(labelText: '名称前缀'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addBodyCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '剧本默认内容',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final count = int.tryParse(
                                    addCountCtrl.text.trim(),
                                  );
                                  if (count == null ||
                                      count < 1 ||
                                      count > 20) {
                                    throw StateError('数量必须是 1-20 的整数');
                                  }
                                  final prefix =
                                      addPrefixCtrl.text.trim().isEmpty
                                      ? '新剧本'
                                      : addPrefixCtrl.text.trim();
                                  final rows = buildBatchAddScriptItems(
                                    count: count,
                                    startingIndex: scriptList.length + 1,
                                    prefix: prefix,
                                    scriptData: addBodyCtrl.text,
                                  );
                                  final created = await postScriptsBatchAddByProjectId(
                                    token,
                                    projectId: p.id,
                                    data: rows,
                                  );
                                  scriptList.addAll(
                                    created.scripts.map(
                                      (script) => ScriptBrief(
                                        legacyId: script.legacyId,
                                        name: script.name,
                                        extractState: script.extractState,
                                      ),
                                    ),
                                  );
                                  try {
                                    statsRef[0] =
                                        await fetchProjectStatsByProjectId(
                                          token,
                                          p.id,
                                        );
                                  } catch (_) {}
                                  setLocalState(() {
                                    selectedIdsCtrl.text =
                                        encodeLegacyIdSelection(
                                          scriptList.map(
                                            (script) => script.legacyId,
                                          ),
                                        );
                                    final nextDiagnosis =
                                        diagnoseScriptBatchWorkbench(
                                          selectedIds: scriptList.map(
                                            (script) => script.legacyId,
                                          ),
                                          scripts: scriptList,
                                          previewRows: previewRows,
                                        );
                                    scriptTaskLine[0] =
                                        buildScriptBatchWorkbenchFollowUp(
                                          actionSummary:
                                              '已批量创建 ${created.inserted} 条剧本。',
                                          diagnosis: nextDiagnosis,
                                        );
                                  });
                                  setDialogState(() => saving[0] = false);
                                  setDialogState(() {});
                                }),
                          child: const Text('批量创建'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '上下文预览',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        if (previewRows.isEmpty)
                          Text(
                            scriptList.isEmpty
                                ? '暂无可预览剧本。'
                                : scriptList
                                      .take(6)
                                      .map(
                                        (script) =>
                                            '#${script.legacyId} ${script.name ?? ''} · 提取状态 ${script.extractState ?? 0}',
                                      )
                                      .join('\n'),
                            style: Theme.of(dialogCtx).textTheme.bodySmall,
                          )
                        else
                          ...previewRows
                              .take(6)
                              .map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '#${row.legacyId} ${row.name ?? ''} · 提取状态 ${row.extractState ?? 0} · 素材 ${summarizeRelatedScriptAssets(row.relatedAssets)}',
                                    style: Theme.of(
                                      dialogCtx,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                        if ((scriptTaskLine[0] ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            scriptTaskLine[0]!,
                            style: Theme.of(dialogCtx).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localBusy
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      filterCtrl.dispose();
      selectedIdsCtrl.dispose();
      groupSizeCtrl.dispose();
      addCountCtrl.dispose();
      addPrefixCtrl.dispose();
      addBodyCtrl.dispose();
    }
  }
}
