part of '../../../../../home_page.dart';

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
      text: encodeNumericIdSelection(
        scriptList.map((script) => script.numericId),
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
    var previewRows = <ScriptWorkbenchDetailRow>[];

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
          selectedIdsCtrl.text = encodeNumericIdSelection(
            scriptList.map((script) => script.numericId),
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
                  ? previewRows.map((row) => row.numericId)
                  : scriptList.map((script) => script.numericId);
              final selectedIds = parseNumericIdSelection(selectedIdsCtrl.text);
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
                      selectedIdsCtrl.text = encodeNumericIdSelection(
                        rows.map((row) => row.numericId),
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
                                          '#${row.numericId}:${row.extractState ?? 0}',
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
                            projectNumericId: p.numericId,
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

              return _buildProjectScriptsWorkbenchDialogView(
                dialogCtx: dialogCtx,
                localBusy: localBusy,
                infoLine: infoLine,
                filterCtrl: filterCtrl,
                previewRows: previewRows,
                selectedIdsCtrl: selectedIdsCtrl,
                diagnosis: diagnosis,
                recommendedAction: recommendedAction,
                recommendedActionLabel: recommendedActionLabel,
                groupSizeCtrl: groupSizeCtrl,
                addCountCtrl: addCountCtrl,
                addPrefixCtrl: addPrefixCtrl,
                addBodyCtrl: addBodyCtrl,
                scriptList: scriptList,
                scriptTaskLine: scriptTaskLine[0],
                onReadContext: () => runAction(() async {
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
                    selectedIdsCtrl.text = encodeNumericIdSelection(
                      rows.map((row) => row.numericId),
                    );
                  });
                }),
                onUsePreviewOrAll: () {
                  setLocalState(() {
                    selectedIdsCtrl.text = encodeNumericIdSelection(
                      previewOrLocalIds,
                    );
                  });
                },
                onReloadScripts: () => runAction(() async {
                  await reloadScriptsAndStats(setLocalState);
                }),
                onRunRecommendedAction: recommendedAction == null
                    ? null
                    : () => runAction(recommendedAction!),
                onExportSelected: () => runAction(() async {
                  final selected = parseNumericIdSelection(
                    selectedIdsCtrl.text,
                  );
                  if (selected.isEmpty) {
                    throw StateError('请先填写至少一个剧本 id');
                  }
                  final zip = await exportScriptsZip(token, selected);
                  setLocalState(() {
                    final nextDiagnosis = diagnoseScriptBatchWorkbench(
                      selectedIds: selected,
                      scripts: scriptList,
                      previewRows: previewRows,
                    );
                    scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                      actionSummary:
                          '已导出 ${selected.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
                      diagnosis: nextDiagnosis,
                    );
                  });
                  setDialogState(() {});
                }),
                onPollSelected: () => runAction(() async {
                  final selected = parseNumericIdSelection(
                    selectedIdsCtrl.text,
                  );
                  if (selected.isEmpty) {
                    throw StateError('请先填写至少一个剧本 id');
                  }
                  final rows = await pollScriptExtractState(token, selected);
                  final synced = syncScriptExtractStates(scriptList, rows);
                  final syncedPreviewRows = syncScriptPreviewExtractStates(
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
                                  '#${row.numericId}:${row.extractState ?? 0}',
                            )
                            .join(' · ');
                  setLocalState(() {
                    final nextDiagnosis = diagnoseScriptBatchWorkbench(
                      selectedIds: selected,
                      scripts: scriptList,
                      previewRows: previewRows,
                    );
                    scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                      actionSummary: '已轮询 ${selected.length} 条剧本提取状态：$sample',
                      diagnosis: nextDiagnosis,
                    );
                  });
                  setDialogState(() {});
                }),
                onExtractSelected: () => runAction(() async {
                  final selected = parseNumericIdSelection(
                    selectedIdsCtrl.text,
                  );
                  if (selected.isEmpty) {
                    throw StateError('请先填写至少一个剧本 id');
                  }
                  final groupSize = int.tryParse(groupSizeCtrl.text.trim());
                  final accepted = await startScriptAssetExtract(
                    token,
                    projectNumericId: p.numericId,
                    scriptNumericIds: selected,
                    groupSize: groupSize,
                  );
                  final rows = await pollScriptExtractState(token, selected);
                  final synced = syncScriptExtractStates(scriptList, rows);
                  final syncedPreviewRows = syncScriptPreviewExtractStates(
                    previewRows,
                    rows,
                  );
                  scriptList
                    ..clear()
                    ..addAll(synced);
                  previewRows = syncedPreviewRows;
                  setLocalState(() {
                    final nextDiagnosis = diagnoseScriptBatchWorkbench(
                      selectedIds: selected,
                      scripts: scriptList,
                      previewRows: previewRows,
                    );
                    scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                      actionSummary:
                          '已提交 ${selected.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
                      diagnosis: nextDiagnosis,
                    );
                  });
                  setDialogState(() {});
                }),
                onBatchCreate: () => runAction(() async {
                  final count = int.tryParse(addCountCtrl.text.trim());
                  if (count == null || count < 1 || count > 20) {
                    throw StateError('数量必须是 1-20 的整数');
                  }
                  final prefix = addPrefixCtrl.text.trim().isEmpty
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
                        numericId: script.numericId,
                        name: script.name,
                        extractState: script.extractState,
                      ),
                    ),
                  );
                  try {
                    statsRef[0] = await fetchProjectStatsByProjectId(
                      token,
                      p.id,
                    );
                  } catch (_) {}
                  setLocalState(() {
                    selectedIdsCtrl.text = encodeNumericIdSelection(
                      scriptList.map((script) => script.numericId),
                    );
                    final nextDiagnosis = diagnoseScriptBatchWorkbench(
                      selectedIds: scriptList.map((script) => script.numericId),
                      scripts: scriptList,
                      previewRows: previewRows,
                    );
                    scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                      actionSummary: '已批量创建 ${created.inserted} 条剧本。',
                      diagnosis: nextDiagnosis,
                    );
                  });
                  setDialogState(() => saving[0] = false);
                  setDialogState(() {});
                }),
                onClose: () => Navigator.of(dialogCtx).pop(),
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
