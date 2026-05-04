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
  StoryboardListRecommendedAction action,
) {
  switch (action) {
    case StoryboardListRecommendedAction.addStoryboard:
      return '继续新增分镜';
    case StoryboardListRecommendedAction.refreshProductionSummary:
      return '刷新制作视图';
    case StoryboardListRecommendedAction.openBatchWorkbench:
      return '进入分镜出图工作台';
    case StoryboardListRecommendedAction.editStoryboard:
      return '补充分镜提示词';
  }
}

String describeStoryboardBatchWorkbenchRecommendedAction(
  StoryboardBatchWorkbenchRecommendedAction action,
) {
  switch (action) {
    case StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary:
      return '同步制作视图';
    case StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards:
      return '全选可出图分镜';
    case StoryboardBatchWorkbenchRecommendedAction.generateSelected:
      return '批量发起出图';
    case StoryboardBatchWorkbenchRecommendedAction.previewSelected:
      return '读取当前预览';
    case StoryboardBatchWorkbenchRecommendedAction.exportSelected:
      return '导出所选 ZIP';
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

String buildStoryboardListFollowUp({
  required String actionSummary,
  required StoryboardListDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardListRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
}

String buildStoryboardBatchWorkbenchFollowUp({
  required String actionSummary,
  required StoryboardBatchWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeStoryboardBatchWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
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
