// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product workbench launchers extension for _HomePageState.
/// Handles opening various workbench dialogs (novels, scripts, etc.).
extension _HomePageProductWorkbenchLaunchers on _HomePageState {
  Future<void> _studioScriptOpenNovelWorkbench(
    ProjectRow project,
    List<ListNovelsResponse?> novelsRef,
    List<bool> novelsBusy,
    Future<void> Function() reloadAssetsAndStats,
  ) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    await openNovelWorkbenchDialog(
      ctx: context,
      l10n: l10n,
      setDialogState: (fn) {
        if (mounted) setState(fn);
      },
      token: token,
      project: project,
      novelsRef: novelsRef,
      novelsBusy: novelsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      parseNumericIdList: parseNumericIdList,
      buildSearchSection: _buildNovelWorkbenchSearchSection,
      buildImportSection: _buildNovelWorkbenchImportSection,
      buildCreateSection: _buildNovelWorkbenchCreateSection,
      buildEditSection: _buildNovelWorkbenchEditSection,
      buildDeleteSection: _buildNovelWorkbenchDeleteSection,
      buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
    );
    await reloadAssetsAndStats();
    kStudioSnapshotBus.invalidate(StudioSnapshotInvalidation.workbenchMedia);
  }

  Future<void> _studioScriptOpenScriptsWorkbench(
    ProjectRow project,
    List<ScriptBrief> scriptList,
    List<bool> saving,
    List<bool> scriptTaskBusy,
    List<String?> scriptTaskLine,
    List<ProjectStats?> statsRef,
    Future<void> Function() reloadScripts,
  ) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    await openProjectScriptsWorkbenchDialog(
      ctx: context,
      l10n: l10n,
      setDialogState: (fn) {
        if (mounted) setState(fn);
      },
      token: token,
      project: project,
      saving: saving,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
    );
    await reloadScripts();
    kStudioSnapshotBus.invalidate(StudioSnapshotInvalidation.workbenchMedia);
  }
}
