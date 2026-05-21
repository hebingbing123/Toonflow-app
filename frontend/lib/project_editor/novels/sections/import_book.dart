part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchImportSection on _HomePageState {
  Widget _buildNovelWorkbenchImportSection({
    required AppLocalizations l10n,
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
    required TextEditingController importBatchUrlsCtrl,
    required TextEditingController importScheduleDelayMinutesCtrl,
    required TextEditingController importScheduleRepeatMinutesCtrl,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importBatchSizeCtrl,
    required TextEditingController importExecutionSideCtrl,
    required TextEditingController importIntakeStatusCtrl,
    required TextEditingController importIntakeNoteCtrl,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
    required NovelCrawlAuthOverride? crawlAuthOverride,
    required void Function(NovelCrawlAuthOverride? value) setCrawlAuthOverride,
  }) {
    void updatePreviewRows(
      List<ParsedNovelChapter> rows,
      String message, {
      bool dropEmptyBodies = false,
    }) {
      final normalized = reindexParsedNovelChapters(
        l10n,
        rows,
        dropEmptyBodies: dropEmptyBodies,
      );
      applyImportPreview(normalized, message);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsWorkbenchImportSectionTitle,
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.projectEditorNovelsWorkbenchImportStudioHint,
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(ctx).textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: importUrlCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchImportCrawlUrlLabel,
            helperText: l10n.projectEditorNovelsWorkbenchImportCrawlUrlHelper,
          ),
        ),
        const SizedBox(height: 8),
        StudioNovelCrawlAuthSection(
          accessToken: token,
          projectId: project.id,
          siteUrlProvider: () {
            final url = importUrlCtrl.text.trim();
            return url.isEmpty ? null : url;
          },
          onOverrideChanged: setCrawlAuthOverride,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: importBatchUrlsCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchImportBatchUrlsLabel,
            helperText: l10n.projectEditorNovelsWorkbenchImportBatchUrlsHelper,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: importScheduleDelayMinutesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      l10n.projectEditorNovelsWorkbenchImportScheduleDelayLabel,
                  helperText:
                      l10n.projectEditorNovelsWorkbenchImportScheduleDelayHelper,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: TextField(
                controller: importScheduleRepeatMinutesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      l10n.projectEditorNovelsWorkbenchImportScheduleRepeatLabel,
                  helperText:
                      l10n.projectEditorNovelsWorkbenchImportScheduleRepeatHelper,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed:
                  localBusy || importExecutionSideCtrl.text.trim() != 'server'
                      ? null
                      : () => _runNovelWorkbenchAction(
                            ctx: ctx,
                            setDialogState: setDialogState,
                            setLocalState: setLocalState,
                            novelsBusy: novelsBusy,
                            setLocalBusy: setLocalBusy,
                            action: () => _createNovelCrawlSchedule(
                              l10n: l10n,
                              token: token,
                              project: project,
                              batchUrls: importBatchUrlsCtrl.text,
                              delayMinutes:
                                  int.tryParse(importScheduleDelayMinutesCtrl.text.trim()) ??
                                      0,
                              repeatMinutes: int.tryParse(
                                importScheduleRepeatMinutesCtrl.text.trim(),
                              ),
                              intakeStatus: importIntakeStatusCtrl.text.trim(),
                              intakeNote: importIntakeNoteCtrl.text.trim().isEmpty
                                  ? null
                                  : importIntakeNoteCtrl.text.trim(),
                              applyInfoLine: updateInfoLine,
                            ),
                          ),
              child: Text(l10n.projectEditorNovelsWorkbenchImportCreateScheduleButton),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed:
                  localBusy || importExecutionSideCtrl.text.trim() != 'server'
                      ? null
                      : () => _runNovelWorkbenchAction(
                            ctx: ctx,
                            setDialogState: setDialogState,
                            setLocalState: setLocalState,
                            novelsBusy: novelsBusy,
                            setLocalBusy: setLocalBusy,
                            action: () => _listNovelCrawlSchedules(
                              l10n: l10n,
                              token: token,
                              project: project,
                              applyInfoLine: updateInfoLine,
                            ),
                          ),
              child: Text(l10n.projectEditorNovelsWorkbenchImportListSchedulesButton),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed:
                  localBusy || importExecutionSideCtrl.text.trim() != 'server'
                      ? null
                      : () => _runNovelWorkbenchAction(
                            ctx: ctx,
                            setDialogState: setDialogState,
                            setLocalState: setLocalState,
                            novelsBusy: novelsBusy,
                            setLocalBusy: setLocalBusy,
                            action: () => _showNovelCrawlObservability(
                              l10n: l10n,
                              token: token,
                              project: project,
                              applyInfoLine: updateInfoLine,
                            ),
                          ),
              child: Text(
                l10n.projectEditorNovelsWorkbenchImportRefreshObservabilityButton,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: localBusy
                ? null
                : () => _runNovelWorkbenchAction(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    setLocalState: setLocalState,
                    novelsBusy: novelsBusy,
                    setLocalBusy: setLocalBusy,
                    action: () => _crawlNovelSourcePreview(
                      l10n: l10n,
                      token: token,
                      project: project,
                      importUrlCtrl: importUrlCtrl,
                      importRawTextCtrl: importRawTextCtrl,
                      importExecutionSideCtrl: importExecutionSideCtrl,
                      applyInfoLine: updateInfoLine,
                      applyImportPreview: applyImportPreview,
                      crawlAuth: crawlAuthOverride,
                    ),
                  ),
            child: Text(l10n.projectEditorNovelsWorkbenchImportCrawlPreparseButton),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: importRawTextCtrl,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchImportRawPasteLabel,
            helperText: l10n.projectEditorNovelsWorkbenchImportRawPasteHelper,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: importBatchSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsWorkbenchImportBatchSizeLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: localBusy
                  ? null
                  : () {
                      final rows = _parseNovelImportPreview(
                        l10n,
                        importRawTextCtrl.text,
                      );
                      applyImportPreview(
                        rows,
                        rows.isEmpty
                            ? l10n.projectEditorNovelsActionPreparseResultEmpty
                            : l10n.projectEditorNovelsActionPreparseResultOk(
                                rows.length,
                              ),
                      );
                    },
              child: Text(l10n.projectEditorNovelsWorkbenchImportPreparseButton),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: localBusy
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _importNovelWorkbenchChapters(
                        l10n: l10n,
                        token: token,
                        project: project,
                        chapters: importPreviewRows,
                        batchSize:
                            int.tryParse(importBatchSizeCtrl.text.trim()) ?? 10,
                        intakeSourceMode: importExecutionSideCtrl.text.trim(),
                        intakeSourceUrl: importUrlCtrl.text.trim(),
                        intakeStatus: importIntakeStatusCtrl.text.trim(),
                        intakeNote: importIntakeNoteCtrl.text.trim().isEmpty
                            ? null
                            : importIntakeNoteCtrl.text.trim(),
                        refreshWorkbench: refreshWorkbench,
                        setLocalState: setLocalState,
                        applyInfoLine: updateInfoLine,
                      ),
                    ),
              child: Text(
                l10n.projectEditorNovelsWorkbenchImportParsedChaptersButton,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: localBusy || importExecutionSideCtrl.text.trim() != 'server'
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _importNovelWorkbenchViaServerCrawl(
                        l10n: l10n,
                        token: token,
                        project: project,
                        intakeSourceUrl: importUrlCtrl.text.trim(),
                        intakeStatus: importIntakeStatusCtrl.text.trim(),
                        intakeNote: importIntakeNoteCtrl.text.trim().isEmpty
                            ? null
                            : importIntakeNoteCtrl.text.trim(),
                        refreshWorkbench: refreshWorkbench,
                        setLocalState: setLocalState,
                        applyInfoLine: updateInfoLine,
                        crawlAuth: crawlAuthOverride,
                      ),
                    ),
              child: Text(l10n.projectEditorNovelsWorkbenchImportServerImportButton),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: localBusy || importExecutionSideCtrl.text.trim() != 'server'
                  ? null
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _importNovelWorkbenchViaServerCrawlBatch(
                        l10n: l10n,
                        token: token,
                        project: project,
                        batchUrls: importBatchUrlsCtrl.text,
                        intakeStatus: importIntakeStatusCtrl.text.trim(),
                        intakeNote: importIntakeNoteCtrl.text.trim().isEmpty
                            ? null
                            : importIntakeNoteCtrl.text.trim(),
                        refreshWorkbench: refreshWorkbench,
                        setLocalState: setLocalState,
                        applyInfoLine: updateInfoLine,
                        crawlAuth: crawlAuthOverride,
                      ),
                    ),
              child: Text(
                l10n.projectEditorNovelsWorkbenchImportServerBatchButton,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: importExecutionSideCtrl.text.isEmpty
                    ? 'client'
                    : importExecutionSideCtrl.text,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsWorkbenchImportExecutionSideLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'client',
                    child: Text(
                      l10n.projectEditorNovelsWorkbenchImportExecutionSideClient,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'server',
                    child: Text(
                      l10n.projectEditorNovelsWorkbenchImportExecutionSideServer,
                    ),
                  ),
                ],
                onChanged: (value) {
                  importExecutionSideCtrl.text = value ?? 'client';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: importIntakeStatusCtrl.text.isEmpty
                    ? 'pending_review'
                    : importIntakeStatusCtrl.text,
                decoration: InputDecoration(
                  labelText:
                      l10n.projectEditorNovelsWorkbenchImportIntakeStatusAfterImportLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'draft',
                    child: Text(l10n.projectEditorNovelsIntakeStatusValueDraft),
                  ),
                  DropdownMenuItem(
                    value: 'pending_review',
                    child: Text(l10n.projectEditorNovelsIntakeStatusValuePendingReview),
                  ),
                  DropdownMenuItem(
                    value: 'admitted',
                    child: Text(l10n.projectEditorNovelsIntakeStatusValueAdmitted),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text(l10n.projectEditorNovelsIntakeStatusValueRejected),
                  ),
                ],
                onChanged: (value) {
                  importIntakeStatusCtrl.text = value ?? 'pending_review';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: importIntakeNoteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsWorkbenchImportIntakeNoteLabel,
                  helperText:
                      l10n.projectEditorNovelsWorkbenchImportIntakeNoteHelper,
                ),
              ),
            ),
          ],
        ),
        if (importPreviewRows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: studioInsetPanelDecoration(ctx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.projectEditorNovelsActionImportPreviewAreaTitle(
                          importPreviewRows.length,
                        ),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: localBusy
                          ? null
                          : () {
                              updatePreviewRows([
                                ...importPreviewRows,
                                ParsedNovelChapter(
                                  chapterIndex: importPreviewRows.length + 1,
                                  chapter: l10n
                                      .projectEditorNovelsActionImportPreviewSupplementChapterTitle(
                                        importPreviewRows.length + 1,
                                      ),
                                  chapterData: '',
                                ),
                              ], l10n.projectEditorNovelsActionImportPreviewAppendChapter);
                            },
                      child: Text(
                        l10n.projectEditorNovelsWorkbenchImportPreviewAddChapterButton,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...importPreviewRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                    decoration: BoxDecoration(
                      border: Border.all(color: studioPanelBorderColor(ctx)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${row.chapterIndex}',
                                style: Theme.of(ctx).textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n
                                  .projectEditorNovelsWorkbenchImportPreviewDeleteChapterTooltip,
                              onPressed: localBusy
                                  ? null
                                  : () {
                                      final updated =
                                          List<ParsedNovelChapter>.from(
                                            importPreviewRows,
                                          )..removeAt(index);
                                      updatePreviewRows(
                                        updated,
                                        l10n.projectEditorNovelsActionImportPreviewDeletedRow(
                                          row.chapterIndex,
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: ValueKey(
                            'import-preview-title-${row.chapterIndex}-${row.chapter}',
                          ),
                          initialValue: row.chapter,
                          decoration: InputDecoration(
                            labelText: l10n
                                .projectEditorNovelsWorkbenchImportPreviewChapterTitleField,
                          ),
                          onChanged: (value) {
                            final updated = List<ParsedNovelChapter>.from(
                              importPreviewRows,
                            );
                            updated[index] = row.copyWith(chapter: value);
                            updatePreviewRows(
                              updated,
                              l10n.projectEditorNovelsActionImportPreviewRowTitleUpdated(
                                row.chapterIndex,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey(
                            'import-preview-body-${row.chapterIndex}-${row.chapterData.length}',
                          ),
                          initialValue: row.chapterData,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n
                                .projectEditorNovelsWorkbenchImportPreviewChapterBodyField,
                          ),
                          onChanged: (value) {
                            final updated = List<ParsedNovelChapter>.from(
                              importPreviewRows,
                            );
                            updated[index] = row.copyWith(chapterData: value);
                            updatePreviewRows(
                              updated,
                              l10n.projectEditorNovelsActionImportPreviewRowBodyUpdated(
                                row.chapterIndex,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Text(
                  l10n.projectEditorNovelsActionImportPreviewFooterNote,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                if (importPreviewRows.length > 12) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.projectEditorNovelsActionImportPreviewLongListHint,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
