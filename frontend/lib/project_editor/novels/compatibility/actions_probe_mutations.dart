part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelsProbeMutationActions on _HomePageState {
  List<Widget> _buildProjectNovelsProbeMutationActions({
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
        onPressed: disabled || novelsRef[0] == null || novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final ids = novelsRef[0]!.items.map((e) => e.numericId).toList();
                  final msg = await postNovelEventsGenerateEvents(
                    token,
                    projectUuid: p.id,
                    novelIds: ids.take(3).toList(),
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeMutationGenerateEventsSnackbar(msg)),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeMutationGenerateEventsButton),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await appendNovelsUnderProject(
                    token,
                    const [],
                    projectUuid: p.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeMutationAddNovelEmptySnackbar),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeMutationAddNovelEmptyButton),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await batchDeleteNovelsUnderProject(token, p.id, const []);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeMutationBatchDeleteUnexpected200Snackbar),
                    ),
                  );
                } catch (e) {
                  if (!ctx.mounted) return;
                  if (e is RustApiException && e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.projectEditorNovelsProbeMutationBatchDeleteExpected400Snackbar,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeMutationBatchDeleteEmptyButton),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await deleteNovelByProjectUuid(token, p.id, 0);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsProbeMutationDeleteNovelUnexpected200Snackbar),
                    ),
                  );
                } catch (e) {
                  if (!ctx.mounted) return;
                  if (e is RustApiException && e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.projectEditorNovelsProbeMutationDeleteNovelExpected400Snackbar,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeMutationDeleteNovelZeroButton),
      ),
      TextButton(
        onPressed: disabled || novelsRef[0] == null || novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                final l10n = resolveAppLocalizationsForErrors(ctx);
                setDialogState(() => novelsBusy[0] = true);
                final n = novelsRef[0]!.items.first;
                try {
                  await updateNovelByProjectUuid(
                    token,
                    projectUuid: p.id,
                    id: n.numericId,
                    index: n.chapterIndex,
                    reel: n.reel ?? '',
                    chapter: n.chapter,
                    chapterData: n.chapterData,
                    event: n.event ?? '',
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorNovelsProbeMutationUpdateNovelNoopSnackbar(n.numericId),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(describeUserVisibleApiError(l10n, e))),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: Text(resolveAppLocalizationsForErrors(ctx).projectEditorNovelsProbeMutationUpdateNovelNoopButton),
      ),
    ];
  }
}
