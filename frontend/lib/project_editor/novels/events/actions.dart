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
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await fetchNovelEventsPaged(
                    token,
                    projectUuid: p.id,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.list.isNotEmpty ? pg.list.first : null;
                  final snack = first != null
                      ? l10n.projectEditorNovelsProbeEventsGetEventsSnackbarWithFirst(
                          pg.total,
                          first.numericId,
                          first.eventName,
                        )
                      : l10n.projectEditorNovelsProbeEventsGetEventsSnackbarTotalOnly(pg.total);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(snack)),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeEventsGetEventsButton),
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
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await fetchNovelEventsPaged(
                    token,
                    projectUuid: p.id,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.list.isNotEmpty ? pg.list.first : null;
                  final snack = first != null
                      ? l10n.projectEditorNovelsProbeEventsGetEventsSnackbarWithFirst(
                          pg.total,
                          first.numericId,
                          first.eventName,
                        )
                      : l10n.projectEditorNovelsProbeEventsGetEventsSnackbarTotalOnly(pg.total);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(snack)),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeEventsBatchDeleteEmptyButton),
      ),
    ];
  }
}
