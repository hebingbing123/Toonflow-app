part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelWorkbenchSearchSection on _HomePageState {
  Widget _buildNovelWorkbenchSearchSection({
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
          decoration: const InputDecoration(
            labelText: '搜索章节关键字',
            helperText: '调用 GET /projects/{project_uuid}/novels?search=',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: searchIntakeStatusCtrl.text.isEmpty
                    ? ''
                    : searchIntakeStatusCtrl.text,
                decoration: const InputDecoration(labelText: '准入状态'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('全部状态')),
                  DropdownMenuItem(value: 'draft', child: Text('draft')),
                  DropdownMenuItem(
                    value: 'pending_review',
                    child: Text('pending_review'),
                  ),
                  DropdownMenuItem(value: 'admitted', child: Text('admitted')),
                  DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                ],
                onChanged: (value) {
                  searchIntakeStatusCtrl.text = value ?? '';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: searchIntakeSourceCtrl.text.isEmpty
                    ? ''
                    : searchIntakeSourceCtrl.text,
                decoration: const InputDecoration(labelText: '接入来源'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('全部来源')),
                  DropdownMenuItem(value: 'manual', child: Text('manual')),
                  DropdownMenuItem(
                    value: 'whole_book_import',
                    child: Text('whole_book_import'),
                  ),
                  DropdownMenuItem(
                    value: 'crawler_client',
                    child: Text('crawler_client'),
                  ),
                  DropdownMenuItem(
                    value: 'crawler_server',
                    child: Text('crawler_server'),
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
                        token: token,
                        project: project,
                        searchCtrl: searchCtrl,
                        searchIntakeStatusCtrl: searchIntakeStatusCtrl,
                        searchIntakeSourceCtrl: searchIntakeSourceCtrl,
                        applyResult: applyResult,
                      ),
                    ),
              child: const Text('搜索'),
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
                      updateInfoLine('已清空章节筛选条件。');
                    },
              child: const Text('清空筛选'),
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
