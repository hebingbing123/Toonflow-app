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
    return buildProjectNovelsWorkbenchSection(
      ctx: ctx,
      novels: novels,
      novelsLoading: novelsLoading,
      novelsBusy: novelsBusy,
      assetsBusy: assetsBusy,
      assetsLoading: assetsLoading,
      assetsScriptFilterLoading: assetsScriptFilterLoading,
      openWorkbench: () => openNovelWorkbenchDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        project: p,
        novelsRef: novelsRef,
        novelsBusy: novelsBusy,
        reloadAssetsAndStats: reloadAssetsAndStats,
        parseNumericIdList: parseNumericIdList,
        buildPreviewSection: _buildNovelWorkbenchPreviewSection,
        buildSearchSection: _buildNovelWorkbenchSearchSection,
        buildCreateSection: _buildNovelWorkbenchCreateSection,
        buildEditSection: _buildNovelWorkbenchEditSection,
        buildDeleteSection: _buildNovelWorkbenchDeleteSection,
        buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
      ),
      refreshNovels: () async {
        setDialogState(() => novelsLoading[0] = true);
        try {
          await reloadAssetsAndStats();
        } finally {
          if (ctx.mounted) {
            setDialogState(() => novelsLoading[0] = false);
          }
        }
      },
      generateEvents: () async {
        setDialogState(() => novelsBusy[0] = true);
        try {
          final ids = novels.take(3).map((e) => e.numericId).toList();
          final message = await postNovelEventsGenerateEvents(
            token,
            projectNumericId: p.numericId,
            novelIds: ids,
          );
          if (!ctx.mounted) return;
          await reloadAssetsAndStats();
          if (!ctx.mounted) return;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('已为章节 ${ids.join(', ')} 触发事件生成：$message')),
          );
        } on RustApiException catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
          }
        } finally {
          if (ctx.mounted) {
            setDialogState(() => novelsBusy[0] = false);
          }
        }
      },
    );
  }
}
