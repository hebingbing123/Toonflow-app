part of 'dialog_support.dart';

class ProjectScriptsWorkbenchController {
  const ProjectScriptsWorkbenchController({
    required this.ctx,
    required this.token,
    required this.project,
    required this.setDialogState,
    required this.saving,
    required this.scriptTaskBusy,
    required this.scriptTaskLine,
    required this.scriptList,
    required this.statsRef,
    required this.session,
  });

  final BuildContext ctx;
  final String token;
  final ProjectRow project;
  final StateSetter setDialogState;
  final List<bool> saving;
  final List<bool> scriptTaskBusy;
  final List<String?> scriptTaskLine;
  final List<ScriptBrief> scriptList;
  final List<ProjectStats?> statsRef;
  final ProjectScriptsWorkbenchSession session;

  Future<void> runAction(
    StateSetter setLocalState,
    Future<void> Function() action,
  ) async {
    setLocalState(() => session.localBusy = true);
    setDialogState(() => scriptTaskBusy[0] = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (ctx.mounted) {
        setDialogState(() => scriptTaskBusy[0] = false);
      }
      setLocalState(() => session.localBusy = false);
    }
  }

  Future<void> reloadScriptsAndStats(StateSetter setLocalState) async {
    final detail = await fetchProjectByProjectId(token, project.id);
    scriptList
      ..clear()
      ..addAll(detail.scripts);
    try {
      statsRef[0] = await fetchProjectStatsByProjectId(token, project.id);
    } catch (_) {}
    setLocalState(() {
      session.infoLine = scriptList.isEmpty
          ? '刷新完成，当前没有剧本。'
          : '刷新完成，共 ${scriptList.length} 条剧本。';
      session.syncSelectionFromScripts(scriptList);
    });
    setDialogState(() {});
  }

  Future<void> readContext(StateSetter setLocalState) async {
    final rows = await postScriptsGetScriptApiByProjectId(
      token,
      project.id,
      name: session.filterCtrl.text.trim(),
    );
    setLocalState(() {
      session.previewRows = rows;
      session.infoLine = rows.isEmpty
          ? '上下文读取完成，但没有匹配剧本。'
          : '已读取 ${rows.length} 条剧本上下文。';
      session.selectedIdsCtrl.text = encodeNumericIdSelection(
        rows.map((row) => row.numericId),
      );
    });
  }

  void usePreviewOrAll(StateSetter setLocalState) {
    setLocalState(() {
      session.selectedIdsCtrl.text = encodeNumericIdSelection(
        session.previewRows.isNotEmpty
            ? session.previewRows.map((row) => row.numericId)
            : scriptList.map((script) => script.numericId),
      );
    });
  }

  void _setFollowUp({
    required StateSetter setLocalState,
    required List<int> selectedIds,
    required String actionSummary,
  }) {
    setLocalState(() {
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        selectedIds: selectedIds,
        scripts: scriptList,
        previewRows: session.previewRows,
      );
      scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
        actionSummary: actionSummary,
        diagnosis: nextDiagnosis,
      );
    });
    setDialogState(() {});
  }

  Future<void> exportSelected(StateSetter setLocalState) async {
    final selected = session.selectedIds();
    if (selected.isEmpty) {
      throw StateError('请先填写至少一个剧本 id');
    }
    final zip = await exportScriptsZip(token, selected);
    _setFollowUp(
      setLocalState: setLocalState,
      selectedIds: selected,
      actionSummary:
          '已导出 ${selected.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
    );
  }

  Future<void> pollSelected(StateSetter setLocalState) async {
    final selected = session.selectedIds();
    if (selected.isEmpty) {
      throw StateError('请先填写至少一个剧本 id');
    }
    final rows = await pollScriptExtractState(token, selected);
    final synced = syncScriptExtractStates(scriptList, rows);
    final syncedPreviewRows = syncScriptPreviewExtractStates(
      session.previewRows,
      rows,
    );
    scriptList
      ..clear()
      ..addAll(synced);
    session.previewRows = syncedPreviewRows;
    final sample = rows.isEmpty
        ? '当前均为 idle 或已完成'
        : rows
              .take(3)
              .map((row) => '#${row.numericId}:${row.extractState ?? 0}')
              .join(' · ');
    _setFollowUp(
      setLocalState: setLocalState,
      selectedIds: selected,
      actionSummary: '已轮询 ${selected.length} 条剧本提取状态：$sample',
    );
  }

  Future<void> extractSelected(StateSetter setLocalState) async {
    final selected = session.selectedIds();
    if (selected.isEmpty) {
      throw StateError('请先填写至少一个剧本 id');
    }
    final groupSize = int.tryParse(session.groupSizeCtrl.text.trim());
    final accepted = await startScriptAssetExtract(
      token,
      projectUuid: project.id,
      projectNumericId: project.numericId,
      scriptNumericIds: selected,
      groupSize: groupSize,
    );
    final rows = await pollScriptExtractState(token, selected);
    final synced = syncScriptExtractStates(scriptList, rows);
    final syncedPreviewRows = syncScriptPreviewExtractStates(
      session.previewRows,
      rows,
    );
    scriptList
      ..clear()
      ..addAll(synced);
    session.previewRows = syncedPreviewRows;
    _setFollowUp(
      setLocalState: setLocalState,
      selectedIds: selected,
      actionSummary:
          '已提交 ${selected.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
    );
  }

  Future<void> batchCreate(StateSetter setLocalState) async {
    final count = int.tryParse(session.addCountCtrl.text.trim());
    if (count == null || count < 1 || count > 20) {
      throw StateError('数量必须是 1-20 的整数');
    }
    final prefix = session.addPrefixCtrl.text.trim().isEmpty
        ? '新剧本'
        : session.addPrefixCtrl.text.trim();
    final rows = buildBatchAddScriptItems(
      count: count,
      startingIndex: scriptList.length + 1,
      prefix: prefix,
      scriptData: session.addBodyCtrl.text,
    );
    final created = await postScriptsBatchAddByProjectId(
      token,
      projectId: project.id,
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
      statsRef[0] = await fetchProjectStatsByProjectId(token, project.id);
    } catch (_) {}
    setLocalState(() {
      session.selectedIdsCtrl.text = encodeNumericIdSelection(
        scriptList.map((script) => script.numericId),
      );
    });
    _setFollowUp(
      setLocalState: setLocalState,
      selectedIds: scriptList.map((script) => script.numericId).toList(),
      actionSummary: '已批量创建 ${created.inserted} 条剧本。',
    );
    setDialogState(() => saving[0] = false);
  }

  String recommendedActionLabel() {
    return describeScriptBatchWorkbenchRecommendedAction(
      session.diagnosis(scriptList: scriptList).recommendedAction,
    );
  }

  Future<void> runRecommendedAction(StateSetter setLocalState) {
    switch (session.diagnosis(scriptList: scriptList).recommendedAction) {
      case ScriptBatchWorkbenchRecommendedAction.syncContext:
        return readContext(setLocalState);
      case ScriptBatchWorkbenchRecommendedAction.pollSelected:
        return pollSelected(setLocalState);
      case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
        return extractSelected(setLocalState);
      case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
        return exportSelected(setLocalState);
    }
  }
}
