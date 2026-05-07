import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import 'import_parser.dart';

part 'workbench_launcher_controllers.dart';
part 'workbench_launcher_state.dart';
part 'workbench_launcher_helpers.dart';

Future<void> openNovelWorkbenchDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ListNovelsResponse?> novelsRef,
  required List<bool> novelsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  required List<int> Function(String raw) parseNumericIdList,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required TextEditingController searchCtrl,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(List<NovelRow> rows, String message) applyResult,
  })
  buildSearchSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required List<ParsedNovelChapter> importPreviewRows,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(String value) updateInfoLine,
    required TextEditingController importUrlCtrl,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importBatchSizeCtrl,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
  })
  buildImportSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController createChapterCtrl,
    required TextEditingController createBodyCtrl,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildCreateSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required TextEditingController patchIntakeStatusCtrl,
    required TextEditingController patchIntakeSourceUrlCtrl,
    required TextEditingController patchIntakeNoteCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildEditSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController deleteNovelIdCtrl,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildDeleteSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController numericIdsCtrl,
    required TextEditingController batchDeleteIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildSnapshotSection,
}) async {
  final currentItems = novelsRef[0]?.items ?? const <NovelRow>[];
  final first = currentItems.isNotEmpty ? currentItems.first : null;
  final last = currentItems.isNotEmpty ? currentItems.last : null;
  final ctrls = _NovelWorkbenchControllers.fromItems(
    currentItems: currentItems,
    first: first,
    last: last,
  );

  final local = _NovelWorkbenchLocalState.fromItems(currentItems);

  Future<void> refreshWorkbench(StateSetter setLocalState) async {
    await refreshNovelWorkbenchLocalState(
      setLocalState: setLocalState,
      reloadAssetsAndStats: reloadAssetsAndStats,
      novelsRef: novelsRef,
      ctrls: ctrls,
      local: local,
    );
  }

  try {
    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            void setLocalBusy(bool value) {
              setLocalState(() => local.localBusy = value);
            }

            void updateInfoLine(String value) {
              setLocalState(() => local.infoLine = value);
            }

            final viewportWidth = MediaQuery.sizeOf(dialogCtx).width;
            final dialogWidth = viewportWidth.isFinite
                ? viewportWidth.clamp(320.0, 760.0)
                : 760.0;
            return AlertDialog(
              title: const Text('章节工作台'),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        local.infoLine,
                        style: Theme.of(dialogCtx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (local.previewRows.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                dialogCtx,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前章节预览',
                                style: Theme.of(dialogCtx).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              ...local.previewRows.map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '#${row.numericId} · ${row.chapter} · ${row.intakeSource ?? 'unknown'} / ${row.intakeStatus ?? 'unset'} · 事件状态 ${row.eventState}',
                                    style: Theme.of(
                                      dialogCtx,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      buildSearchSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        searchCtrl: ctrls.searchCtrl,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        refreshWorkbench: refreshWorkbench,
                        applyResult: (rows, message) {
                          applyNovelWorkbenchSearchResult(
                            setLocalState: setLocalState,
                            local: local,
                            rows: rows,
                            message: message,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      buildImportSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        importPreviewRows: local.importPreviewRows,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        refreshWorkbench: refreshWorkbench,
                        updateInfoLine: updateInfoLine,
                        importUrlCtrl: ctrls.importUrlCtrl,
                        importRawTextCtrl: ctrls.importRawTextCtrl,
                        importBatchSizeCtrl: ctrls.importBatchSizeCtrl,
                        applyImportPreview: (rows, message) {
                          setLocalState(() {
                            local.importPreviewRows = rows;
                            local.infoLine = message;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      buildCreateSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        createChapterCtrl: ctrls.createChapterCtrl,
                        createBodyCtrl: ctrls.createBodyCtrl,
                        selectedNovelIdCtrl: ctrls.selectedNovelIdCtrl,
                        patchChapterCtrl: ctrls.patchChapterCtrl,
                        patchBodyCtrl: ctrls.patchBodyCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildEditSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        selectedNovelIdCtrl: ctrls.selectedNovelIdCtrl,
                        patchChapterCtrl: ctrls.patchChapterCtrl,
                        patchBodyCtrl: ctrls.patchBodyCtrl,
                        patchIntakeStatusCtrl: ctrls.patchIntakeStatusCtrl,
                        patchIntakeSourceUrlCtrl:
                            ctrls.patchIntakeSourceUrlCtrl,
                        patchIntakeNoteCtrl: ctrls.patchIntakeNoteCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildDeleteSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        deleteNovelIdCtrl: ctrls.deleteNovelIdCtrl,
                        generateIdsCtrl: ctrls.generateIdsCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildSnapshotSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: local.localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        numericIdsCtrl: ctrls.numericIdsCtrl,
                        batchDeleteIdsCtrl: ctrls.batchDeleteIdsCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: local.localBusy
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
    ctrls.dispose();
  }
}
