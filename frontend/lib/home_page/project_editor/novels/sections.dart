part of '../../../home_page.dart';

part 'sections/search.dart';
part 'sections/create.dart';
part 'sections/edit.dart';
part 'sections/delete_snapshot.dart';

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

}
