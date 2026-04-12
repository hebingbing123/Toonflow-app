part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsWorkbench on _HomePageState {
  Widget _buildProjectNovelEventsWorkbenchSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
  }) {
    final events = novelEventsRef[0]?.items ?? const <NovelEventRow>[];
    final first = events.isNotEmpty ? events.first : null;
    final summaryLine = summarizeNovelEventRows(events);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          ctx,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('事件工作台', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            first == null
                ? '用显式表单管理事件搜索、创建、更新、删除和批量删除，减少对 HTTP probe 按钮的依赖。'
                : '$summaryLine；首条 #${first.numericId} ${first.name}。',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        novelEventsLoading[0] ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () => _openNovelEventsWorkbenchDialog(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        novelsRef: novelsRef,
                        novelEventsRef: novelEventsRef,
                        novelsBusy: novelsBusy,
                        novelEventsLoading: novelEventsLoading,
                      ),
                child: const Text('打开事件工作台'),
              ),
              OutlinedButton(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        novelEventsLoading[0] ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () async {
                        setDialogState(() => novelEventsLoading[0] = true);
                        try {
                          novelEventsRef[0] =
                              await fetchProjectNovelEventsByProjectId(
                                token,
                                p.id,
                              );
                        } on RustApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => novelEventsLoading[0] = false);
                          }
                        }
                      },
                child: Text(novelEventsLoading[0] ? '刷新事件…' : '刷新事件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int> _chapterIndexesToNumericIds({
    required List<NovelRow> chapters,
    required List<int> indexes,
  }) {
    if (chapters.isEmpty || indexes.isEmpty) {
      return const <int>[];
    }
    final byIndex = <int, int>{
      for (final chapter in chapters) chapter.chapterIndex: chapter.numericId,
    };
    return indexes.map((index) => byIndex[index]).whereType<int>().toList();
  }
}
