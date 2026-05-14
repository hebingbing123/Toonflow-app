part of '../../home_page.dart';

/// Encapsulates storyboard workbench view-state calculation so the main panel
/// file can stay focused on owning controllers and composing sections.
extension _StoryboardWorkbenchState on _StoryboardWorkbenchPanelState {
  void _setResolutionValue(String value) {
    _applyWorkbenchState(() => _resolution = value);
  }

  void _setModeValue(String value) {
    _applyWorkbenchState(() => _mode = value);
  }

  void _setAudioValue(bool value) {
    _applyWorkbenchState(() => _audio = value);
  }

  ({VoidCallback? recommendedAction, String recommendedActionLabel})
  _recommendedActionState(
    StoryboardWorkbenchDiagnosis diagnosis,
    List<int> knownTrackIds,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    VoidCallback? recommendedAction;
    var recommendedActionLabel =
        describeStoryboardWorkbenchRecommendedAction(
          l10n,
          diagnosis.recommendedAction,
        );
    switch (diagnosis.recommendedAction) {
      case StoryboardWorkbenchRecommendedAction.syncProductionData:
        recommendedAction = _saving || _loadingProduction
            ? null
            : () => _runDialogAction(_syncProductionDataAction);
      case StoryboardWorkbenchRecommendedAction.readCurrentPreview:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_readCurrentPreview);
      case StoryboardWorkbenchRecommendedAction.prepareVideoTrack:
        recommendedAction = _saving ? null : () => _prepareVideoTrack(knownTrackIds);
      case StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_generateVideoPrompt);
      case StoryboardWorkbenchRecommendedAction.refreshVideoData:
        recommendedAction = _saving || _loadingWorkbench
            ? null
            : () => _runDialogAction(_refreshVideoDataAction);
        if (_loadingWorkbench) {
          recommendedActionLabel = l10n.scriptEditorStoryboardsRefreshing;
        }
      case StoryboardWorkbenchRecommendedAction.submitVideoGeneration:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_submitVideoGeneration);
        if (_saving) {
          recommendedActionLabel = l10n.scriptEditorStoryboardsVideoGenerating;
        }
    }
    return (
      recommendedAction: recommendedAction,
      recommendedActionLabel: recommendedActionLabel,
    );
  }

  ({
    List<int> knownTrackIds,
    List<VideoItem> storyboardVideos,
    StoryboardWorkbenchDiagnosis diagnosis,
    VoidCallback? recommendedAction,
    String recommendedActionLabel,
  })
  _buildWorkbenchViewState() {
    final knownTrackIds = _knownTrackIds();
    final storyboardVideos = _storyboardVideos();
    final diagnosis = _currentDiagnosis();
    final recommended = _recommendedActionState(diagnosis, knownTrackIds);
    return (
      knownTrackIds: knownTrackIds,
      storyboardVideos: storyboardVideos,
      diagnosis: diagnosis,
      recommendedAction: recommended.recommendedAction,
      recommendedActionLabel: recommended.recommendedActionLabel,
    );
  }
}
