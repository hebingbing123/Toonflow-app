part of 'diagnosis.dart';

class StoryboardListDiagnosis {
  const StoryboardListDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final StoryboardListRecommendedAction recommendedAction;
}

class StoryboardBatchWorkbenchDiagnosis {
  const StoryboardBatchWorkbenchDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final StoryboardBatchWorkbenchRecommendedAction recommendedAction;
}

class StoryboardWorkbenchDiagnosis {
  const StoryboardWorkbenchDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final StoryboardWorkbenchRecommendedAction recommendedAction;
}

enum StoryboardListRecommendedAction {
  addStoryboard,
  refreshProductionSummary,
  openBatchWorkbench,
  editStoryboard,
}

enum StoryboardBatchWorkbenchRecommendedAction {
  syncProductionSummary,
  selectReadyStoryboards,
  generateSelected,
  previewSelected,
  exportSelected,
}

enum StoryboardWorkbenchRecommendedAction {
  syncProductionData,
  readCurrentPreview,
  prepareVideoTrack,
  generateDefaultVideoPrompt,
  refreshVideoData,
  submitVideoGeneration,
}

String describeStoryboardListRecommendedAction(
  AppLocalizations l10n,
  StoryboardListRecommendedAction action,
) {
  switch (action) {
    case StoryboardListRecommendedAction.addStoryboard:
      return l10n.scriptEditorStoryboardsRecommendAddStoryboard;
    case StoryboardListRecommendedAction.refreshProductionSummary:
      return l10n.scriptEditorStoryboardsRecommendRefreshProduction;
    case StoryboardListRecommendedAction.openBatchWorkbench:
      return l10n.scriptEditorStoryboardsRecommendOpenBatchWorkbench;
    case StoryboardListRecommendedAction.editStoryboard:
      return l10n.scriptEditorStoryboardsRecommendEditPrompts;
  }
}

String describeStoryboardBatchWorkbenchRecommendedAction(
  AppLocalizations l10n,
  StoryboardBatchWorkbenchRecommendedAction action,
) {
  switch (action) {
    case StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary:
      return l10n.scriptEditorStoryboardBatchRecommendSyncProduction;
    case StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards:
      return l10n.scriptEditorStoryboardBatchRecommendSelectReady;
    case StoryboardBatchWorkbenchRecommendedAction.generateSelected:
      return l10n.scriptEditorStoryboardBatchRecommendGenerateSelected;
    case StoryboardBatchWorkbenchRecommendedAction.previewSelected:
      return l10n.scriptEditorStoryboardBatchRecommendPreviewSelected;
    case StoryboardBatchWorkbenchRecommendedAction.exportSelected:
      return l10n.scriptEditorStoryboardBatchRecommendExportSelected;
  }
}

String describeStoryboardWorkbenchRecommendedAction(
  AppLocalizations l10n,
  StoryboardWorkbenchRecommendedAction action,
) {
  switch (action) {
    case StoryboardWorkbenchRecommendedAction.syncProductionData:
      return l10n.scriptEditorStoryboardsVideoRecommendSyncProductionData;
    case StoryboardWorkbenchRecommendedAction.readCurrentPreview:
      return l10n.scriptEditorStoryboardsVideoRecommendReadCurrentPreview;
    case StoryboardWorkbenchRecommendedAction.prepareVideoTrack:
      return l10n.scriptEditorStoryboardsVideoRecommendPrepareVideoTrack;
    case StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt:
      return l10n
          .scriptEditorStoryboardsVideoRecommendGenerateDefaultVideoPrompt;
    case StoryboardWorkbenchRecommendedAction.refreshVideoData:
      return l10n.scriptEditorStoryboardsVideoRecommendRefreshVideoData;
    case StoryboardWorkbenchRecommendedAction.submitVideoGeneration:
      return l10n.scriptEditorStoryboardsVideoRecommendSubmitVideoGeneration;
  }
}

String buildStoryboardListFollowUp(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardListDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardListRecommendedAction(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.scriptEditorStoryboardsFollowUpLine(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

String buildStoryboardBatchWorkbenchFollowUp(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardBatchWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardBatchWorkbenchRecommendedAction(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.scriptEditorStoryboardBatchFollowUpLine(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

String buildStoryboardWorkbenchFollowUp(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardWorkbenchRecommendedAction(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.scriptEditorStoryboardsFollowUpLine(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

String buildStoryboardWorkbenchActionNotice(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required String detail,
}) {
  final nextAction = describeStoryboardWorkbenchRecommendedAction(
    l10n,
    recommendedAction,
  );
  return l10n.scriptEditorStoryboardsFollowUpLine(
    actionSummary,
    nextAction,
    detail,
  );
}

String normalizeStoryboardWorkbenchErrorMessage(
  AppLocalizations l10n,
  String raw,
) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return l10n.scriptEditorStoryboardsVideoErrorNoExtraDetail;
  }
  final normalized = trimmed
      .replaceFirst(kStudioApiErrorLinePrefixPattern, '')
      .replaceFirst(RegExp(r'^RustApiException\([^)]*\):\s*'), '');
  if (normalized.isEmpty) {
    return l10n.scriptEditorStoryboardsVideoErrorNoExtraDetail;
  }
  return normalized;
}

String buildStoryboardWorkbenchFailureNotice(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required Object error,
  required String fallbackDetail,
}) {
  final reason = normalizeStoryboardWorkbenchErrorMessage(
    l10n,
    describeUserVisibleApiError(l10n, error),
  );
  return buildStoryboardWorkbenchActionNotice(
    l10n,
    actionSummary: actionSummary,
    recommendedAction: recommendedAction,
    detail: l10n.scriptEditorStoryboardsVideoFailureReasonDetail(
      reason,
      fallbackDetail,
    ),
  );
}

String buildStoryboardWorkbenchLoadingNotice(
  AppLocalizations l10n, {
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required String detail,
}) {
  return buildStoryboardWorkbenchActionNotice(
    l10n,
    actionSummary: actionSummary,
    recommendedAction: recommendedAction,
    detail: detail,
  );
}
