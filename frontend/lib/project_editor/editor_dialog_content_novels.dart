part of '../../home_page.dart';

extension _HomePageProjectEditorDialogContentNovels on _HomePageState {
  Widget _buildProjectEditorNovelsAndEventsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.projectEditorNovelsAndEventsTitle, style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 8),
        buildProjectNovelsWorkbenchSection(
          ctx: ctx,
          l10n: l10n,
          novels: dialogState.novelsRef[0]?.items ?? const <NovelRow>[],
          novelsLoading: dialogState.novelsLoading,
          novelsBusy: dialogState.novelsBusy,
          assetsBusy: dialogState.assetsBusy,
          assetsLoading: dialogState.assetsLoading,
          assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
          openWorkbench: () => openNovelWorkbenchDialog(
            ctx: ctx,
            l10n: l10n,
            setDialogState: setDialogState,
            token: token,
            project: p,
            novelsRef: dialogState.novelsRef,
            novelsBusy: dialogState.novelsBusy,
            reloadAssetsAndStats: () =>
                dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
            parseNumericIdList: parseNumericIdList,
            buildSearchSection: _buildNovelWorkbenchSearchSection,
            buildImportSection: _buildNovelWorkbenchImportSection,
            buildCreateSection: _buildNovelWorkbenchCreateSection,
            buildEditSection: _buildNovelWorkbenchEditSection,
            buildDeleteSection: _buildNovelWorkbenchDeleteSection,
            buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
          ),
          refreshNovels: () async {
            setDialogState(() => dialogState.novelsLoading[0] = true);
            try {
              await dialogState.reloadAssetsAndStats(token, p.id, p.numericId);
            } finally {
              if (ctx.mounted) {
                setDialogState(() => dialogState.novelsLoading[0] = false);
              }
            }
          },
          generateEvents: () async {
            setDialogState(() => dialogState.novelsBusy[0] = true);
            try {
              final ids = pickEventGeneratableNovelIds(
                dialogState.novelsRef[0]?.items ?? const <NovelRow>[],
                maxCount: 3,
              );
              if (ids.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorNovelsEventsGenerateEmptyAdmitted),
                    ),
                  );
                }
                return;
              }
              final message = await postNovelEventsGenerateEvents(
                token,
                projectUuid: p.id,
                novelIds: ids,
              );
              if (!ctx.mounted) return;
              await dialogState.reloadAssetsAndStats(token, p.id, p.numericId);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.projectEditorNovelsEventsGenerateTriggered(
                      ids.join(', '),
                      message,
                    ),
                  ),
                ),
              );
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(describeUserVisibleApiError(l10n, e)),
                  ),
                );
              }
            } finally {
              if (ctx.mounted) {
                setDialogState(() => dialogState.novelsBusy[0] = false);
              }
            }
          },
        ),
        const SizedBox(height: 8),
        buildProjectNovelEventsWorkbenchSection(
          ctx: ctx,
          events:
              dialogState.novelEventsRef[0]?.items ?? const <NovelEventRow>[],
          novelsLoading: dialogState.novelsLoading,
          novelsBusy: dialogState.novelsBusy,
          novelEventsLoading: dialogState.novelEventsLoading,
          assetsBusy: dialogState.assetsBusy,
          assetsLoading: dialogState.assetsLoading,
          assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
          openWorkbench: () => openNovelEventsWorkbenchDialog(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            project: p,
            novelsRef: dialogState.novelsRef,
            novelEventsRef: dialogState.novelEventsRef,
            novelsBusy: dialogState.novelsBusy,
            novelEventsLoading: dialogState.novelEventsLoading,
            parseNumericIdList: parseNumericIdList,
            chapterIndexesToNumericIds: chapterIndexesToNumericIds,
          ),
          refreshEvents: () async {
            setDialogState(() => dialogState.novelEventsLoading[0] = true);
            try {
              dialogState.novelEventsRef[0] =
                  await fetchProjectNovelEventsByProjectId(token, p.id);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(describeUserVisibleApiError(l10n, e)),
                  ),
                );
              }
            } finally {
              if (ctx.mounted) {
                setDialogState(() => dialogState.novelEventsLoading[0] = false);
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
          novelsRef: dialogState.novelsRef,
          novelEventsRef: dialogState.novelEventsRef,
          novelsLoading: dialogState.novelsLoading,
          novelsBusy: dialogState.novelsBusy,
          novelEventsLoading: dialogState.novelEventsLoading,
          assetsBusy: dialogState.assetsBusy,
          assetsLoading: dialogState.assetsLoading,
          assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
        ),
      ],
    );
  }
}
