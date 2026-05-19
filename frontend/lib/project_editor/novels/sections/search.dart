import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
part of '../../../../home_page.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorNovelsWorkbenchSearchKeywordLabel,
            helperText: l10n.projectEditorNovelsWorkbenchSearchKeywordHelper,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: searchIntakeStatusCtrl.text.isEmpty
                    ? ''
                    : searchIntakeStatusCtrl.text,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsWorkbenchSearchIntakeStatusLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.projectEditorNovelsWorkbenchSearchIntakeStatusAll),
                  ),
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
                  searchIntakeStatusCtrl.text = value ?? '';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: searchIntakeSourceCtrl.text.isEmpty
                    ? ''
                    : searchIntakeSourceCtrl.text,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorNovelsWorkbenchSearchIntakeSourceLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.projectEditorNovelsWorkbenchSearchIntakeSourceAll),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text(l10n.projectEditorNovelsIntakeSourceValueManual),
                  ),
                  DropdownMenuItem(
                    value: 'whole_book_import',
                    child: Text(l10n.projectEditorNovelsIntakeSourceValueWholeBookImport),
                  ),
                  DropdownMenuItem(
                    value: 'crawler_client',
                    child: Text(l10n.projectEditorNovelsIntakeSourceValueCrawlerClient),
                  ),
                  DropdownMenuItem(
                    value: 'crawler_server',
                    child: Text(l10n.projectEditorNovelsIntakeSourceValueCrawlerServer),
                  ),
                ],
                onChanged: (value) {
                  searchIntakeSourceCtrl.text = value ?? '';
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
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
    );
  }
}
