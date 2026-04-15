part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsWorkbenchDialog on _HomePageState {
  /// 事件工作台负责搜索、创建、更新和删除事件，避免 section 混入完整表单流。
  Future<void> _openNovelEventsWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
  }) async {
    await openNovelEventsWorkbenchDialog(
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
    );
  }
}
