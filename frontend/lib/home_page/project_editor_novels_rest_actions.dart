part of '../home_page.dart';

extension _HomePageProjectEditorNovelsRestActions on _HomePageState {
  List<Widget> _buildProjectRestNovelsProbeActions({
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
                    chapter: 'novel_probe_$ts',
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('已 POST 测试章节')),
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
        child: const Text('POST 测试章节'),
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
                      content: Text(
                        'GET …/novels/${first.legacyId}：${row.chapter}',
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
        child: const Text('GET 首条小说'),
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
                    search: 'novel',
                    page: 1,
                    limit: 5,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'GET …/novels?search=novel&page=1&limit=5：total=${pg.total}，本页 ${pg.items.length} 条',
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
        child: const Text('GET 小说 search+分页'),
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
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('已 PATCH 首条小说 chapter')),
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
        child: const Text('PATCH 首条小说'),
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
                      SnackBar(content: Text('已 DELETE 末条小说 #${last.legacyId}')),
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
        child: const Text('DELETE 末条小说'),
      ),
    ];
  }
}
