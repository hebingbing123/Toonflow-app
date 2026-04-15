part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsWorkbench on _HomePageState {
  Widget _buildProjectNovelEventsWorkbenchSection({
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
    final events = novelEventsRef[0]?.items ?? const <NovelEventRow>[];
    return buildProjectNovelEventsWorkbenchSection(
      ctx: ctx,
      events: events,
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
        parseNumericIdList: _parseNumericIdList,
        chapterIndexesToNumericIds: _chapterIndexesToNumericIds,
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
    );
  }

  List<int> _chapterIndexesToNumericIds({
    required List<NovelRow> chapters,
    required List<int> indexes,
  }) {
    if (chapters.isEmpty || indexes.isEmpty) {
      return const <int>[];
    }
    final byIndex = <int, int>{
      for (final chapter in chapters) chapter.chapterIndex: chapter.numericId,
    };
    return indexes.map((index) => byIndex[index]).whereType<int>().toList();
  }
}
