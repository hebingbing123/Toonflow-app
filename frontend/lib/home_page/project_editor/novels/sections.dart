part of '../../../home_page.dart';

/// Keeps novels workbench form sections close to the novels domain so the main
/// workbench file can stay focused on dialog orchestration.
extension _HomePageProjectEditorNovelWorkbenchSections on _HomePageState {
  Widget _buildNovelWorkbenchPreviewSection({
    required BuildContext context,
    required List<NovelRow> previewRows,
  }) {
    if (previewRows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前章节预览', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ...previewRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '#${row.numericId} · ${row.chapter} · 事件状态 ${row.eventState}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelWorkbenchSearchSection({
    required BuildContext ctx,
    required BuildContext dialogCtx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required TextEditingController searchCtrl,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(List<NovelRow> rows, String infoLine) applyResult,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            labelText: '搜索章节关键字',
            helperText: '调用 GET /projects/{project_uuid}/novels?search=',
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
                  : () => _runNovelWorkbenchAction(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      setLocalState: setLocalState,
                      novelsBusy: novelsBusy,
                      setLocalBusy: setLocalBusy,
                      action: () => _searchNovelWorkbenchRows(
                        token: token,
                        project: project,
                        searchCtrl: searchCtrl,
                        applyResult: applyResult,
                      ),
                    ),
              child: const Text('搜索'),
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
              child: const Text('刷新列表'),
            ),
          ],
        ),
      ],
    );
  }
}
