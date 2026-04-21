part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelsProbeReadActions on _HomePageState {
  List<Widget> _buildProjectNovelsProbeReadActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsBusy,
    required bool disabled,
  }) {
    return [
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await fetchNovelWorkbenchPaged(
                    token,
                    p.numericId,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.data.isNotEmpty ? pg.data.first : null;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        first != null
                            ? 'POST …/novels/get-novel：total=${pg.total} · 首行 #${first.numericId} ${first.chapter}'
                            : 'POST …/novels/get-novel：total=${pg.total}',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST get-novel'),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final rows = await fetchNovelWorkbenchFullRows(
                    token,
                    p.numericId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('POST …/novels/get-novel-data：${rows.length} 条'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST get-novel-data'),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final idx = await fetchNovelWorkbenchIndex(
                    token,
                    p.numericId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('POST …/novels/get-novel-index：${idx.length} 条'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST get-novel-index'),
      ),
      TextButton(
        onPressed: disabled || novelsRef[0] == null
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final ids = novelsRef[0]!.items.map((e) => e.numericId).toList();
                  final rows = await fetchNovelWorkbenchEventStates(
                    token,
                    p.id,
                    ids,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/novels/get-novel-event-state：${rows.length} 条非 0 状态',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST get-novel-event-state'),
      ),
    ];
  }
}

