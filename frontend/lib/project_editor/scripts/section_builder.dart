import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import '../../script_editor/support.dart';
import 'section_view.dart';

Widget buildProjectScriptsSection({
  required BuildContext ctx,
  required AppLocalizations l10n,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<bool> saving,
  required List<bool> scriptTaskBusy,
  required List<String?> scriptTaskLine,
  required List<ScriptBrief> scriptList,
  required List<ProjectStats?> statsRef,
  required Future<void> Function() openWorkbench,
  required Future<void> Function() openPlanWorkbench,
  required Future<void> Function() openBatchAddDialog,
  required void Function(ScriptBrief script) openScriptEditor,
}) {
  final allScriptIds = scriptList
      .map((script) => script.numericId)
      .toList(growable: false);
  final overviewDiagnosis = diagnoseScriptBatchWorkbench(
    l10n,
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
        l10n,
        selectedIds: allScriptIds,
        scripts: scriptList,
        previewRows: const [],
      );
      setDialogState(() {
        scriptTaskBusy[0] = false;
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.projectEditorScriptsWorkbenchExportAllSummary(
            scriptList.length,
            formatBinarySize(zip.length),
          ),
          diagnosis: nextDiagnosis,
        );
      });
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = l10n.projectEditorScriptsWorkbenchExportAllFailed(
            describeUserVisibleApiErrorResolved(ctx, e),
          );
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
          ? l10n.projectEditorScriptsWorkbenchPollExtractIdleOrComplete
          : rows
                .take(3)
                .map((row) => '#${row.numericId}:${row.extractState ?? 0}')
                .join(' · ');
      if (!ctx.mounted) return;
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        l10n,
        selectedIds: allScriptIds,
        scripts: scriptList,
        previewRows: const [],
      );
      setDialogState(() {
        scriptTaskBusy[0] = false;
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.projectEditorScriptsWorkbenchPollAllSummary(
            scriptList.length,
            sample,
          ),
          diagnosis: nextDiagnosis,
        );
      });
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = l10n.projectEditorScriptsWorkbenchPollAllFailed(
            describeUserVisibleApiErrorResolved(ctx, e),
          );
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
        projectUuid: project.id,
        scriptNumericIds: allScriptIds,
      );
      final rows = await pollScriptExtractState(token, allScriptIds);
      final synced = syncScriptExtractStates(scriptList, rows);
      scriptList
        ..clear()
        ..addAll(synced);
      if (!ctx.mounted) return;
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        l10n,
        selectedIds: allScriptIds,
        scripts: scriptList,
        previewRows: const [],
      );
      setDialogState(() {
        scriptTaskBusy[0] = false;
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.projectEditorScriptsWorkbenchExtractAllSummary(
            scriptList.length,
            accepted.status,
            accepted.message,
          ),
          diagnosis: nextDiagnosis,
        );
      });
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = l10n.projectEditorScriptsWorkbenchExtractAllFailed(
            describeUserVisibleApiErrorResolved(ctx, e),
          );
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
        l10n,
        selectedIds: scriptList.map((item) => item.numericId),
        scripts: scriptList,
        previewRows: const [],
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        saving[0] = false;
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.projectEditorScriptsWorkbenchCreatedScriptFollowUp(
            script.numericId,
          ),
          diagnosis: nextDiagnosis,
        );
      });
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            l10n.projectEditorScriptsWorkbenchCreatedScriptSnackBar(
              script.numericId,
            ),
          ),
        ),
      );
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => saving[0] = false);
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(
          SnackBar(
            content: Text(describeUserVisibleApiErrorResolved(ctx, e)),
          ),
        );
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
      overviewActionLabel =
          l10n.projectEditorScriptsWorkbenchOverviewOpenWorkbenchReadContext;
    case ScriptBatchWorkbenchRecommendedAction.pollSelected:
      overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
          ? null
          : runProjectScriptsPollAll;
      overviewActionLabel =
          l10n.projectEditorScriptsWorkbenchOverviewPollAllExtract;
    case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
      overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
          ? null
          : runProjectScriptsExtractAll;
      overviewActionLabel =
          l10n.projectEditorScriptsWorkbenchOverviewExtractAllAssets;
    case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
      overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
          ? null
          : runProjectScriptsExportAll;
      overviewActionLabel =
          l10n.projectEditorScriptsWorkbenchOverviewExportAllScripts;
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
    ),
    callbacks: ProjectScriptsSectionViewCallbacks(
      onOpenWorkbench: () => openWorkbench(),
      onOpenPlanWorkbench: () => openPlanWorkbench(),
      onOpenBatchAddDialog: () => openBatchAddDialog(),
      onExportAll: runProjectScriptsExportAll,
      onPollAll: runProjectScriptsPollAll,
      onExtractAll: runProjectScriptsExtractAll,
      onCreateEmptyScript: createEmptyScript,
      onOpenScriptEditor: openScriptEditor,
    ),
  );
}
