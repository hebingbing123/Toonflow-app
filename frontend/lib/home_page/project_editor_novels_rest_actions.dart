part of '../home_page.dart';

extension _HomePageProjectEditorNovelsRestActions on _HomePageState {
  List<Widget> _buildProjectRestNovelsActions({
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
    return [
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  await createProjectNovelUnderLegacy(
                    token,
                    p.legacyId,
                    chapter: '新章节_$ts',
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('已新增小说章节')));
                  }
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('新增章节'),
      ),
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                novelsRef[0] == null ||
                novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                final first = novelsRef[0]!.items.first;
                try {
                  final row = await fetchProjectNovelByLegacyIds(
                    token,
                    p.legacyId,
                    first.legacyId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('已读取章节 #${first.legacyId}：${row.chapter}'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('查看首条章节'),
      ),
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await fetchProjectNovelsByLegacyId(
                    token,
                    p.legacyId,
                    search: '章节',
                    page: 1,
                    limit: 5,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        '搜索“章节”：共 ${pg.total} 条，本页 ${pg.items.length} 条',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('搜索章节'),
      ),
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                novelsRef[0] == null ||
                novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                final first = novelsRef[0]!.items.first;
                try {
                  await patchProjectNovelByLegacyIds(
                    token,
                    p.legacyId,
                    first.legacyId,
                    {'chapter': '${first.chapter}·patched'},
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(const SnackBar(content: Text('已更新首条章节标题')));
                  }
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('更新首条章节'),
      ),
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                novelsRef[0] == null ||
                novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                final last = novelsRef[0]!.items.last;
                try {
                  await deleteProjectNovelByLegacyIds(
                    token,
                    p.legacyId,
                    last.legacyId,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('已删除末条章节 #${last.legacyId}')),
                    );
                  }
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('删除末条章节'),
      ),
    ];
  }
}
