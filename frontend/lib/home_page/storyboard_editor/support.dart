import 'dart:collection';

import '../../rust_api.dart';

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
      return '提交视频生成';
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

StoryboardBatchWorkbenchDiagnosis diagnoseStoryboardBatchWorkbench({
  required Iterable<int> selectedIds,
  required Iterable<StoryboardRow> boards,
  required Iterable<ProductionStoryboardItemV1> productionRows,
}) {
  final selected = selectedIds.toList(growable: false);
  final boardRows = boards.toList(growable: false);
  final productionById = <int, ProductionStoryboardItemV1>{
    for (final row in productionRows) row.id: row,
  };

  final readyAcrossAll = boardRows.where((row) {
    return resolveStoryboardGenerationPrompt(
          scriptStoryboard: row,
          productionStoryboard: productionById[row.legacyId],
        ) !=
        null;
  }).length;

  if (selected.isEmpty) {
    if (readyAcrossAll > 0) {
      return StoryboardBatchWorkbenchDiagnosis(
        summary: '当前还没有选择要处理的分镜。',
        detail: '已有 $readyAcrossAll 条分镜具备可用提示词，建议先一键选中可出图分镜，再批量发起出图或导出。',
        recommendedAction:
            StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards,
      );
    }
    return const StoryboardBatchWorkbenchDiagnosis(
      summary: '当前还没有选择要处理的分镜。',
      detail: '建议先同步制作视图，确认 production 侧分镜记录和提示词是否齐全，再决定后续动作。',
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
    );
  }

  var selectedReadyCount = 0;
  var selectedWithImageCount = 0;
  var selectedProductionCoverage = 0;
  for (final legacyId in selected) {
    StoryboardRow? scriptRow;
    for (final row in boardRows) {
      if (row.legacyId == legacyId) {
        scriptRow = row;
        break;
      }
    }
    final productionRow = productionById[legacyId];
    if (productionRow != null) {
      selectedProductionCoverage += 1;
    }
    if (resolveStoryboardGenerationPrompt(
          scriptStoryboard: scriptRow,
          productionStoryboard: productionRow,
        ) !=
        null) {
      selectedReadyCount += 1;
    }
    if ((scriptRow?.filePath ?? productionRow?.url ?? '').trim().isNotEmpty) {
      selectedWithImageCount += 1;
    }
  }

  if (selectedProductionCoverage < selected.length) {
    return StoryboardBatchWorkbenchDiagnosis(
      summary: '所选 ${selected.length} 条分镜还没有全部同步到制作视图。',
      detail: '建议先刷新制作视图，补齐 production 侧分镜快照后再读预览、下载链接或导出。',
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
    );
  }

  if (selectedReadyCount == 0) {
    return const StoryboardBatchWorkbenchDiagnosis(
      summary: '所选分镜都还缺少可直接出图的提示词。',
      detail: '先回到分镜编辑区补全提示词，或同步制作视图确认 production 侧是否已有可复用提示词。',
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
    );
  }

  if (selectedWithImageCount == selected.length) {
    if (selected.length == 1) {
      return const StoryboardBatchWorkbenchDiagnosis(
        summary: '当前所选分镜已经有现成画面。',
        detail: '建议先读取当前预览确认画面是否可直接复用，再决定是否重新发起出图。',
        recommendedAction:
            StoryboardBatchWorkbenchRecommendedAction.previewSelected,
      );
    }
    return StoryboardBatchWorkbenchDiagnosis(
      summary: '所选 ${selected.length} 条分镜都已有现成画面。',
      detail: '可以直接导出所选 ZIP 做集中审阅，必要时再回到单条分镜重跑出图。',
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.exportSelected,
    );
  }

  return StoryboardBatchWorkbenchDiagnosis(
    summary: '所选 ${selected.length} 条分镜里有 $selectedReadyCount 条可直接发起出图。',
    detail: '建议先批量提交出图任务，再回到当前工作台读取预览或下载链接确认结果。',
    recommendedAction:
        StoryboardBatchWorkbenchRecommendedAction.generateSelected,
  );
}

StoryboardWorkbenchDiagnosis diagnoseStoryboardWorkbench({
  required StoryboardRow scriptStoryboard,
  required ProductionStoryboardItemV1? productionStoryboard,
  required Iterable<ProductionStoryboardItemV1> productionStoryboards,
  required Iterable<VideoItem> generatedVideos,
  required Iterable<JobRow> generatingJobs,
  required String? draftImageUrl,
  required String trackIdText,
  required String videoPromptText,
  required String videoDurationText,
}) {
  if (productionStoryboard == null) {
    return const StoryboardWorkbenchDiagnosis(
      summary: '当前分镜还没有同步到制作视图。',
      detail: '建议先同步当前分镜数据，补齐 production 侧的图片、轨道和提示词快照，再继续处理视频流程。',
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.syncProductionData,
    );
  }

  final sourceImage = resolveStoryboardSourceImageUrl(
    productionStoryboard: productionStoryboard,
    draftImageUrl: draftImageUrl,
  );
  if (sourceImage == null) {
    return const StoryboardWorkbenchDiagnosis(
      summary: '当前分镜还没有可用画面。',
      detail: '先读取当前预览或手动保存图片 URL，让视频工作台有明确的输入源。',
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.readCurrentPreview,
    );
  }

  final knownTrackIds = collectStoryboardTrackIds(
    scriptStoryboard: scriptStoryboard,
    productionStoryboard: productionStoryboard,
    productionStoryboards: productionStoryboards,
    generatedVideos: generatedVideos,
  );
  final selectedTrackId = int.tryParse(trackIdText.trim());
  if (selectedTrackId == null || selectedTrackId <= 0) {
    return StoryboardWorkbenchDiagnosis(
      summary: knownTrackIds.isEmpty ? '当前分镜还没有可用视频轨道。' : '当前分镜还没有选定视频轨道。',
      detail: knownTrackIds.isEmpty
          ? '建议先准备视频轨道，再提交视频生成任务。'
          : '已发现轨道 ${knownTrackIds.join(", ")}，建议先回填一个轨道 ID 再继续生成视频。',
      recommendedAction: StoryboardWorkbenchRecommendedAction.prepareVideoTrack,
    );
  }

  final prompt = videoPromptText.trim();
  final duration = int.tryParse(videoDurationText.trim());
  if (prompt.isEmpty || duration == null || duration <= 0) {
    return const StoryboardWorkbenchDiagnosis(
      summary: '视频参数还没有准备完整。',
      detail: '建议先生成默认视频提示词并确认时长，再提交视频任务。',
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt,
    );
  }

  final storyboardVideos = storyboardScopedVideos(
    generatedVideos,
    scriptStoryboard.legacyId,
  );
  if (generatingJobs.isNotEmpty) {
    return StoryboardWorkbenchDiagnosis(
      summary: '当前剧本还有 ${generatingJobs.length} 条视频任务在运行。',
      detail: storyboardVideos.isEmpty
          ? '建议先刷新视频数据，确认当前分镜是否已有新结果，再决定是否继续提交。'
          : '建议先刷新视频数据并检查当前分镜已有候选视频，再决定是否继续提交。',
      recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
    );
  }

  if (storyboardVideos.isNotEmpty) {
    return StoryboardWorkbenchDiagnosis(
      summary: '当前分镜已有 ${storyboardVideos.length} 条视频候选。',
      detail: '可以先检查已有视频结果并设为当前视频；若仍不满意，再按当前参数继续提交新任务。',
      recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
    );
  }

  return const StoryboardWorkbenchDiagnosis(
    summary: '图片、轨道和视频参数都已就绪。',
    detail: '可以直接提交视频生成任务，随后刷新视频数据确认候选结果。',
    recommendedAction:
        StoryboardWorkbenchRecommendedAction.submitVideoGeneration,
  );
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
