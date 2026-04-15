import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../../script_editor/support.dart';
import 'section_view.dart';

Widget buildProjectScriptsSection({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<bool> saving,
  required List<bool> scriptTaskBusy,
  required List<String?> scriptTaskLine,
  required List<ScriptBrief> scriptList,
  required List<ProjectStats?> statsRef,
  required List<Widget> probeActions,
  required Future<void> Function() openWorkbench,
  required Future<void> Function() openBatchAddDialog,
  required void Function(ScriptBrief script) openScriptEditor,
}) {
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
        projectNumericId: project.numericId,
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

  Future<void> createEmptyScript() async {
    setDialogState(() => saving[0] = true);
    try {
      final script = await createScriptUnderProject(token, project.id);
      if (!ctx.mounted) return;
      scriptList.add(
        ScriptBrief(
          numericId: script.numericId,
          name: script.name,
          extractState: script.extractState,
        ),
      );
      try {
        statsRef[0] = await fetchProjectStatsByProjectId(token, project.id);
      } catch (_) {}
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        selectedIds: scriptList.map((item) => item.numericId),
        scripts: scriptList,
        previewRows: const [],
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        saving[0] = false;
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          actionSummary: '已创建剧本 #${script.numericId}。',
          diagnosis: nextDiagnosis,
        );
      });
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已创建剧本 #${script.numericId}')));
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
  }

  VoidCallback? overviewAction;
  String overviewActionLabel;
  switch (overviewDiagnosis.recommendedAction) {
    case ScriptBatchWorkbenchRecommendedAction.syncContext:
      overviewAction = saving[0] || scriptTaskBusy[0]
          ? null
          : () => openWorkbench();
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

  return ProjectScriptsSectionView(
    model: ProjectScriptsSectionViewModel(
      saving: saving[0],
      scriptTaskBusy: scriptTaskBusy[0],
      scriptTaskLine: scriptTaskLine[0],
      scriptList: scriptList,
      overviewDiagnosis: overviewDiagnosis,
      overviewActionLabel: overviewActionLabel,
      overviewAction: overviewAction,
      probeActions: probeActions,
    ),
    callbacks: ProjectScriptsSectionViewCallbacks(
      onOpenWorkbench: () => openWorkbench(),
      onOpenBatchAddDialog: () => openBatchAddDialog(),
      onExportAll: runProjectScriptsExportAll,
      onPollAll: runProjectScriptsPollAll,
      onExtractAll: runProjectScriptsExtractAll,
      onCreateEmptyScript: createEmptyScript,
      onOpenScriptEditor: openScriptEditor,
    ),
  );
}
