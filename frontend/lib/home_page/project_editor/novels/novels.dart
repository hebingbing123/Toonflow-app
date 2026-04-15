part of '../../../home_page.dart';

extension _HomePageProjectEditorNovels on _HomePageState {
  Widget _buildProjectNovelsSection({
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
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('小说与事件', style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 8),
        buildProjectNovelsWorkbenchSection(
          ctx: ctx,
          novels: novelsRef[0]?.items ?? const <NovelRow>[],
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
              final ids = (novelsRef[0]?.items ?? const <NovelRow>[])
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
                SnackBar(content: Text('已为章节 ${ids.join(', ')} 触发事件生成：$message')),
              );
            } on RustApiException catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            } finally {
              if (ctx.mounted) {
                setDialogState(() => novelsBusy[0] = false);
              }
            }
          },
        ),
        const SizedBox(height: 8),
        buildProjectNovelEventsWorkbenchSection(
          ctx: ctx,
          events: novelEventsRef[0]?.items ?? const <NovelEventRow>[],
          novelsLoading: novelsLoading,
          novelsBusy: novelsBusy,
          novelEventsLoading: novelEventsLoading,
          assetsBusy: assetsBusy,
          assetsLoading: assetsLoading,
          assetsScriptFilterLoading: assetsScriptFilterLoading,
          openWorkbench: () => openNovelEventsWorkbenchDialog(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            project: p,
            novelsRef: novelsRef,
            novelEventsRef: novelEventsRef,
            novelsBusy: novelsBusy,
            novelEventsLoading: novelEventsLoading,
            parseNumericIdList: parseNumericIdList,
            chapterIndexesToNumericIds: chapterIndexesToNumericIds,
          ),
          refreshEvents: () async {
            setDialogState(() => novelEventsLoading[0] = true);
            try {
              novelEventsRef[0] = await fetchProjectNovelEventsByProjectId(
                token,
                p.id,
              );
            } on RustApiException catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            } finally {
              if (ctx.mounted) {
                setDialogState(() => novelEventsLoading[0] = false);
              }
            }
          },
        ),
        const SizedBox(height: 8),
        _buildProjectNovelsCompatibilitySection(
          ctx: ctx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          novelsRef: novelsRef,
          novelEventsRef: novelEventsRef,
          novelsLoading: novelsLoading,
          novelsBusy: novelsBusy,
          novelEventsLoading: novelEventsLoading,
          assetsBusy: assetsBusy,
          assetsLoading: assetsLoading,
          assetsScriptFilterLoading: assetsScriptFilterLoading,
        ),
      ],
    );
  }
}
