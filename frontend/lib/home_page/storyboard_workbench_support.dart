import 'dart:collection';

import '../rust_api.dart';

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

enum StoryboardListRecommendedAction {
  addStoryboard,
  refreshProductionSummary,
  openBatchWorkbench,
  editStoryboard,
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

StoryboardListDiagnosis diagnoseStoryboardList({
  required Iterable<StoryboardRow> boards,
  required bool productionSummaryLoaded,
}) {
  final rows = boards.toList(growable: false);
  if (rows.isEmpty) {
    return const StoryboardListDiagnosis(
      summary: '当前剧本还没有分镜。',
      detail: '先新增单条或批量导入分镜，再继续同步制作视图或发起出图。',
      recommendedAction: StoryboardListRecommendedAction.addStoryboard,
    );
  }

  final readyPromptCount = rows
      .where((row) => (row.prompt ?? '').trim().isNotEmpty)
      .length;
  if (!productionSummaryLoaded) {
    return StoryboardListDiagnosis(
      summary: '已维护 ${rows.length} 条分镜，但制作视图还未同步。',
      detail: '建议先刷新制作视图，确认 production 侧是否已生成对应记录，再决定是否继续批量出图。',
      recommendedAction:
          StoryboardListRecommendedAction.refreshProductionSummary,
    );
  }

  if (readyPromptCount == 0) {
    return StoryboardListDiagnosis(
      summary: '已存在 ${rows.length} 条分镜，但都还缺少可用提示词。',
      detail: '先打开单条分镜补全提示词，再进入出图工作台会更稳妥。',
      recommendedAction: StoryboardListRecommendedAction.editStoryboard,
    );
  }

  return StoryboardListDiagnosis(
    summary: '已有 $readyPromptCount/${rows.length} 条分镜可直接进入出图流程。',
    detail: '可以进入分镜出图工作台批量读取制作视图、生成预览并导出所选图片。',
    recommendedAction: StoryboardListRecommendedAction.openBatchWorkbench,
  );
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

List<int> collectStoryboardTrackIds({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  Iterable<ProductionStoryboardItemV1> productionStoryboards = const [],
  Iterable<VideoItem> generatedVideos = const [],
}) {
  final trackIds = SplayTreeSet<int>();

  void addTrackId(int? trackId) {
    if (trackId != null && trackId > 0) {
      trackIds.add(trackId);
    }
  }

  addTrackId(scriptStoryboard?.trackId);
  addTrackId(productionStoryboard?.trackId);
  for (final row in productionStoryboards) {
    addTrackId(row.trackId);
  }
  for (final video in generatedVideos) {
    addTrackId(video.trackId);
  }
  return trackIds.toList(growable: false);
}

List<VideoItem> storyboardScopedVideos(
  Iterable<VideoItem> videos,
  int storyboardId,
) {
  final scoped = videos.where((video) => video.id == storyboardId).toList();
  scoped.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return scoped;
}

String? resolveStoryboardSourceImageUrl({
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftImageUrl,
}) {
  final draft = draftImageUrl?.trim();
  if (draft != null && draft.isNotEmpty) {
    return draft;
  }
  final current = productionStoryboard?.url?.trim();
  if (current == null || current.isEmpty) {
    return null;
  }
  return current;
}

String? resolveStoryboardGenerationPrompt({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
}) {
  final scriptPrompt = scriptStoryboard?.prompt?.trim();
  if (scriptPrompt != null && scriptPrompt.isNotEmpty) {
    return scriptPrompt;
  }
  final productionPrompt = productionStoryboard?.prompt?.trim();
  if (productionPrompt != null && productionPrompt.isNotEmpty) {
    return productionPrompt;
  }
  return null;
}
