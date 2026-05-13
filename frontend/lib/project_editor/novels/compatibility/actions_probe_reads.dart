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
                final l10n = AppLocalizations.of(ctx)!;
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final pg = await fetchNovelWorkbenchPaged(
                    token,
                    projectUuid: p.id,
                    page: 1,
                    limit: 10,
                  );
                  if (!ctx.mounted) return;
                  final first = pg.data.isNotEmpty ? pg.data.first : null;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        first != null
                            ? l10n.projectEditorNovelsProbeReadGetNovelSnackbarWithFirst(
                                pg.total,
                                first.numericId,
                                first.chapter,
                              )
                            : l10n.projectEditorNovelsProbeReadGetNovelSnackbarTotalOnly(pg.total),
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
        child: Text(AppLocalizations.of(ctx)!.projectEditorNovelsProbeReadGetNovelButton),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                final l10n = AppLocalizations.of(ctx)!;
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final rows = await fetchNovelWorkbenchFullRows(
                    token,
                    projectUuid: p.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeReadGetNovelDataSnackbar(rows.length)),
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
        child: Text(AppLocalizations.of(ctx)!.projectEditorNovelsProbeReadGetNovelDataButton),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                final l10n = AppLocalizations.of(ctx)!;
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final idx = await fetchNovelWorkbenchIndex(
                    token,
                    projectUuid: p.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeReadGetNovelIndexSnackbar(idx.length)),
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
        child: Text(AppLocalizations.of(ctx)!.projectEditorNovelsProbeReadGetNovelIndexButton),
      ),
      TextButton(
        onPressed: disabled || novelsRef[0] == null
            ? null
            : () async {
                final l10n = AppLocalizations.of(ctx)!;
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
                        l10n.projectEditorNovelsProbeReadGetNovelEventStateSnackbar(rows.length),
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
        child: Text(AppLocalizations.of(ctx)!.projectEditorNovelsProbeReadGetNovelEventStateButton),
      ),
    ];
  }
}
