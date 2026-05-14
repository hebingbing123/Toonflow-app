part of '../../home_page.dart';

/// Storyboard workbench action extensions.
///
/// Split into focused helper files:
///   - actions/patch_helpers.dart  — 局部返工 dialog 逻辑
///   - actions/video_helpers.dart  — 视频生成/预览逻辑
///   - actions/quality_helpers.dart — 质量门控触发逻辑
extension _StoryboardWorkbenchSharedActions on _StoryboardWorkbenchPanelState {
  Future<void> _notifyStoryboardMutated() async {
    final callback = widget.onStoryboardMutated;
    if (callback == null) {
      return;
    }
    await callback();
  }

  Future<void> _runDialogAction(Future<void> Function() action) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    _applyWorkbenchState(() => _saving = true);
    try {
      await action();
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      _showWorkbenchFailureSnackBar(
        actionSummary: l10n.storyboardActionOperationFailedSummary,
        recommendedAction: _currentDiagnosis().recommendedAction,
        error: e,
        fallbackDetail: l10n.storyboardActionOperationFailedDetail,
      );
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _saving = false);
      }
    }
  }
}
