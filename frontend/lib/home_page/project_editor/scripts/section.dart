part of '../../../../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    final outline = Theme.of(ctx).colorScheme.outline;
    final allScriptIds = scriptList
        .map((script) => script.numericId)
        .toList(growable: false);
    final overviewDiagnosis = diagnoseScriptBatchWorkbench(
      selectedIds: allScriptIds,
      scripts: scriptList,
      previewRows: const [],
    );

    Future<void> runProjectScriptsExportAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final zip = await exportScriptsZip(token, allScriptIds);
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary:
                '已导出 ${scriptList.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '导出失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '导出失败：$e';
          });
        }
      }
    }

    Future<void> runProjectScriptsPollAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final rows = await pollScriptExtractState(token, allScriptIds);
        final synced = syncScriptExtractStates(scriptList, rows);
        scriptList
          ..clear()
          ..addAll(synced);
        final sample = rows.isEmpty
            ? '当前均为 idle 或已完成'
            : rows
                  .take(3)
                  .map((row) => '#${row.numericId}:${row.extractState ?? 0}')
                  .join(' · ');
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary: '已轮询 ${scriptList.length} 条剧本提取状态：$sample',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '轮询提取状态失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '轮询提取状态失败：$e';
          });
        }
      }
    }

    Future<void> runProjectScriptsExtractAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final accepted = await startScriptAssetExtract(
          token,
          projectNumericId: p.numericId,
          scriptNumericIds: allScriptIds,
        );
        final rows = await pollScriptExtractState(token, allScriptIds);
        final synced = syncScriptExtractStates(scriptList, rows);
        scriptList
          ..clear()
          ..addAll(synced);
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary:
                '已提交 ${scriptList.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '提交素材抽取失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '提交素材抽取失败：$e';
          });
        }
      }
    }

    VoidCallback? overviewAction;
    String overviewActionLabel;
    switch (overviewDiagnosis.recommendedAction) {
      case ScriptBatchWorkbenchRecommendedAction.syncContext:
        overviewAction = saving[0] || scriptTaskBusy[0]
            ? null
            : () => _openProjectScriptsWorkbenchDialog(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                saving: saving,
                scriptTaskBusy: scriptTaskBusy,
                scriptTaskLine: scriptTaskLine,
                scriptList: scriptList,
                statsRef: statsRef,
              );
        overviewActionLabel = '打开工作台读取上下文';
      case ScriptBatchWorkbenchRecommendedAction.pollSelected:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsPollAll;
        overviewActionLabel = '轮询全部提取状态';
      case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsExtractAll;
        overviewActionLabel = '提取全部剧本素材';
      case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsExportAll;
        overviewActionLabel = '导出全部剧本';
    }

    return _buildProjectScriptsSectionView(
      ctx: ctx,
      outline: outline,
      p: p,
      saving: saving,
      scriptProbeBusy: scriptProbeBusy,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
      overviewDiagnosis: overviewDiagnosis,
      overviewAction: overviewAction,
      overviewActionLabel: overviewActionLabel,
      onOpenWorkbench: () => _openProjectScriptsWorkbenchDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptTaskBusy: scriptTaskBusy,
        scriptTaskLine: scriptTaskLine,
        scriptList: scriptList,
        statsRef: statsRef,
      ),
      onOpenBatchAddDialog: () => _openBatchAddScriptsDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptTaskLine: scriptTaskLine,
        scriptList: scriptList,
        statsRef: statsRef,
      ),
      onExportAll: runProjectScriptsExportAll,
      onPollAll: runProjectScriptsPollAll,
      onExtractAll: runProjectScriptsExtractAll,
      onCreateEmptyScript: () async {
        setDialogState(() => saving[0] = true);
        try {
          final s = await createScriptUnderProject(token, p.id);
          if (!ctx.mounted) return;
          scriptList.add(
            ScriptBrief(
              numericId: s.numericId,
              name: s.name,
              extractState: s.extractState,
            ),
          );
          try {
            statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
          } catch (_) {}
          final nextDiagnosis = diagnoseScriptBatchWorkbench(
            selectedIds: scriptList.map((script) => script.numericId),
            scripts: scriptList,
            previewRows: const [],
          );
          if (!ctx.mounted) return;
          setDialogState(() {
            saving[0] = false;
            scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
              actionSummary: '已创建剧本 #${s.numericId}。',
              diagnosis: nextDiagnosis,
            );
          });
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text('已创建剧本 #${s.numericId}')));
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
      buildProbeActions: () => _buildProjectScriptsProbeActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        saving: saving,
        scriptProbeBusy: scriptProbeBusy,
        scriptList: scriptList,
      ),
      onOpenScriptEditor: (script) => _openScriptEditor(
        token,
        script.numericId,
        projectId: p.id,
        projectNumericId: p.numericId,
        onScriptTreeMutated: () async {
          final d = await fetchProjectByProjectId(token, p.id);
          if (!ctx.mounted) return;
          scriptList
            ..clear()
            ..addAll(d.scripts);
          try {
            statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
          } catch (_) {}
          setDialogState(() {});
        },
      ),
    );
  }
}
