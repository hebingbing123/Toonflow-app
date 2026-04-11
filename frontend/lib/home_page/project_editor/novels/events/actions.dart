part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsActions on _HomePageState {
  List<Widget> _buildProjectNovelEventsCompatibilityActions({
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
    return [
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                novelEventsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await postLegacyNovelEventsGetEvents(
                    token,
                    p.numericId,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.list.isNotEmpty ? pg.list.first : null;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        first != null
                            ? 'POST …/novels/events/get-events：total=${pg.total} · 首条 #${first.numericId} ${first.eventName}'
                            : 'POST …/novels/events/get-events：total=${pg.total}',
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
        child: const Text('POST events/get-events'),
      ),
      TextButton(
        onPressed:
            novelsBusy[0] ||
                novelsLoading[0] ||
                novelEventsLoading[0] ||
                assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await postLegacyNovelEventsGetEvents(
                    token,
                    p.numericId,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.list.isNotEmpty ? pg.list.first : null;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        first != null
                            ? 'POST …/novels/events/get-events：total=${pg.total} · 首条 #${first.numericId} ${first.eventName}'
                            : 'POST …/novels/events/get-events：total=${pg.total}',
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
        child: const Text('POST events/batch-delete []'),
      ),
    ];
  }
}
