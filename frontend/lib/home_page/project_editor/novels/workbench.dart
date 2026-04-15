part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelsWorkbench on _HomePageState {
  Widget _buildProjectNovelsWorkbenchSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final novels = novelsRef[0]?.items ?? const <NovelRow>[];
    final first = novels.isNotEmpty ? novels.first : null;
    final last = novels.isNotEmpty ? novels.last : null;
    final summaryLine = summarizeNovelRows(novels);
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
          Text('章节工作台', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            first == null
                ? '用显式表单完成章节新增、搜索、查看、更新、删除和事件生成，不再依赖首条/末条 probe 按钮。'
                : '$summaryLine；首条 #${first.numericId} ${first.chapter}，末条 #${last!.numericId} ${last.chapter}。',
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
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () => _openNovelWorkbenchDialog(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        novelsRef: novelsRef,
                        novelsBusy: novelsBusy,
                        reloadAssetsAndStats: reloadAssetsAndStats,
                      ),
                child: const Text('打开章节工作台'),
              ),
              OutlinedButton(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () async {
                        setDialogState(() => novelsLoading[0] = true);
                        try {
                          await reloadAssetsAndStats();
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => novelsLoading[0] = false);
                          }
                        }
                      },
                child: Text(novelsLoading[0] ? '刷新章节…' : '刷新章节'),
              ),
              OutlinedButton(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        novels.isEmpty ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () async {
                        setDialogState(() => novelsBusy[0] = true);
                        try {
                          final ids = novels
                              .take(3)
                              .map((e) => e.numericId)
                              .toList();
                          final message = await postNovelEventsGenerateEvents(
                            token,
                            projectNumericId: p.numericId,
                            novelIds: ids,
                          );
                          if (!ctx.mounted) return;
                          await reloadAssetsAndStats();
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已为章节 ${ids.join(', ')} 触发事件生成：$message',
                              ),
                            ),
                          );
                        } on RustApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(
                              ctx,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => novelsBusy[0] = false);
                          }
                        }
                      },
                child: const Text('为前 3 条生成事件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openNovelWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    await openNovelWorkbenchDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      novelsRef: novelsRef,
      novelsBusy: novelsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      parseNumericIdList: _parseNumericIdList,
      buildPreviewSection: _buildNovelWorkbenchPreviewSection,
      buildSearchSection: _buildNovelWorkbenchSearchSection,
      buildCreateSection: _buildNovelWorkbenchCreateSection,
      buildEditSection: _buildNovelWorkbenchEditSection,
      buildDeleteSection: _buildNovelWorkbenchDeleteSection,
      buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
    );
  }

  List<int> _parseNumericIdList(String raw) {
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toList();
  }
}
