part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchSearchSection on _HomePageState {
  Widget _buildNovelWorkbenchSearchSection({
    required AppLocalizations l10n,
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required TextEditingController searchCtrl,
    required TextEditingController searchIntakeStatusCtrl,
    required TextEditingController searchIntakeSourceCtrl,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(String value) updateInfoLine,
    required void Function(List<NovelRow> rows, String infoLine) applyResult,
  }) {
    return StudioCollapsibleFilterPanel(
      collapsible: true,
      title: l10n.projectEditorNovelsWorkbenchSearchKeywordLabel,
      subtitle: searchCtrl.text.trim().isEmpty
          ? null
          : '${l10n.projectEditorNovelsWorkbenchSearchKeywordLabel}: ${searchCtrl.text.trim()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              labelText: l10n.projectEditorNovelsWorkbenchSearchKeywordLabel,
              helperText: l10n.projectEditorNovelsWorkbenchSearchKeywordHelper,
              isDense: true,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioFilterRow(
            wideLayout: StudioFilterWideLayout.toolbarRow,
            wideBreakpoint: 560,
            children: <Widget>[
              Expanded(
                child: StudioDropdownButtonFormField<String>(
                  initialValue: searchIntakeStatusCtrl.text.isEmpty
                      ? ''
                      : searchIntakeStatusCtrl.text,
                  decoration: InputDecoration(
                    labelText:
                        l10n.projectEditorNovelsWorkbenchSearchIntakeStatusLabel,
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        l10n.projectEditorNovelsWorkbenchSearchIntakeStatusAll,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'draft',
                      child: Text(l10n.projectEditorNovelsIntakeStatusValueDraft),
                    ),
                    DropdownMenuItem(
                      value: 'pending_review',
                      child: Text(
                        l10n.projectEditorNovelsIntakeStatusValuePendingReview,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'admitted',
                      child: Text(
                        l10n.projectEditorNovelsIntakeStatusValueAdmitted,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text(
                        l10n.projectEditorNovelsIntakeStatusValueRejected,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    searchIntakeStatusCtrl.text = value ?? '';
                  },
                ),
              ),
              Expanded(
                child: StudioDropdownButtonFormField<String>(
                  initialValue: searchIntakeSourceCtrl.text.isEmpty
                      ? ''
                      : searchIntakeSourceCtrl.text,
                  decoration: InputDecoration(
                    labelText:
                        l10n.projectEditorNovelsWorkbenchSearchIntakeSourceLabel,
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        l10n.projectEditorNovelsWorkbenchSearchIntakeSourceAll,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text(l10n.projectEditorNovelsIntakeSourceValueManual),
                    ),
                    DropdownMenuItem(
                      value: 'whole_book_import',
                      child: Text(
                        l10n.projectEditorNovelsIntakeSourceValueWholeBookImport,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'crawler_client',
                      child: Text(
                        l10n.projectEditorNovelsIntakeSourceValueCrawlerClient,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'crawler_server',
                      child: Text(
                        l10n.projectEditorNovelsIntakeSourceValueCrawlerServer,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    searchIntakeSourceCtrl.text = value ?? '';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioFilterRow(
            wideLayout: StudioFilterWideLayout.toolbarRow,
            wideBreakpoint: 520,
            children: <Widget>[
              FilledButton.tonal(
                style: studioFormTonalButtonStyle(ctx),
                onPressed: localBusy
                    ? null
                    : () => _runNovelWorkbenchAction(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        novelsBusy: novelsBusy,
                        setLocalBusy: setLocalBusy,
                        action: () => _searchNovelWorkbenchRows(
                          l10n: l10n,
                          token: token,
                          project: project,
                          searchCtrl: searchCtrl,
                          searchIntakeStatusCtrl: searchIntakeStatusCtrl,
                          searchIntakeSourceCtrl: searchIntakeSourceCtrl,
                          applyResult: applyResult,
                        ),
                      ),
                child: Text(l10n.projectEditorNovelsWorkbenchSearchButton),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(ctx),
                onPressed: localBusy
                    ? null
                    : () {
                        setLocalState(() {
                          searchCtrl.clear();
                          searchIntakeStatusCtrl.clear();
                          searchIntakeSourceCtrl.clear();
                        });
                        updateInfoLine(
                          l10n.projectEditorNovelsActionSearchFiltersCleared,
                        );
                      },
                child: Text(l10n.projectEditorNovelsWorkbenchSearchClearFilters),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(ctx),
                onPressed: localBusy
                    ? null
                    : () => _runNovelWorkbenchAction(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        novelsBusy: novelsBusy,
                        setLocalBusy: setLocalBusy,
                        action: () => refreshWorkbench(setLocalState),
                      ),
                child: Text(l10n.projectEditorNovelsWorkbenchSearchRefreshList),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
