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
  StoryboardWorkbenchRecommendedAction action,
) {
  switch (action) {
    case StoryboardWorkbenchRecommendedAction.syncProductionData:
      return '同步当前分镜数据';
    case StoryboardWorkbenchRecommendedAction.readCurrentPreview:
      return '读取当前预览';
    case StoryboardWorkbenchRecommendedAction.prepareVideoTrack:
      return '准备视频轨道';
    case StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt:
      return '生成默认视频提示词';
    case StoryboardWorkbenchRecommendedAction.refreshVideoData:
      return '刷新视频数据';
    case StoryboardWorkbenchRecommendedAction.submitVideoGeneration:
      return '一键生成视频';
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

String buildStoryboardWorkbenchFollowUp({
  required String actionSummary,
  required StoryboardWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
}

String buildStoryboardWorkbenchActionNotice({
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required String detail,
}) {
  final nextAction = describeStoryboardWorkbenchRecommendedAction(
    recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。$detail';
}

String normalizeStoryboardWorkbenchErrorMessage(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '未提供额外错误信息。';
  }
  final normalized = trimmed.replaceFirst(
    RegExp(r'^RustApiException\([^)]*\):\s*'),
    '',
  );
  if (normalized.isEmpty) {
    return '未提供额外错误信息。';
  }
  return normalized;
}

String buildStoryboardWorkbenchFailureNotice({
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required Object error,
  required String fallbackDetail,
}) {
  final reason = normalizeStoryboardWorkbenchErrorMessage(error.toString());
  return buildStoryboardWorkbenchActionNotice(
    actionSummary: actionSummary,
    recommendedAction: recommendedAction,
    detail: '失败原因：$reason。$fallbackDetail',
  );
}

String buildStoryboardWorkbenchLoadingNotice({
  required String actionSummary,
  required StoryboardWorkbenchRecommendedAction recommendedAction,
  required String detail,
}) {
  return buildStoryboardWorkbenchActionNotice(
    actionSummary: actionSummary,
    recommendedAction: recommendedAction,
    detail: detail,
  );
}
