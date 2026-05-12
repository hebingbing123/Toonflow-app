part of 'diagnosis.dart';

StoryboardListDiagnosis diagnoseStoryboardList(
  AppLocalizations l10n, {
  required Iterable<StoryboardRow> boards,
  required bool productionSummaryLoaded,
}) {
  final rows = boards.toList(growable: false);
  if (rows.isEmpty) {
    return StoryboardListDiagnosis(
      summary: l10n.scriptEditorStoryboardsDiagnosisEmptySummary,
      detail: l10n.scriptEditorStoryboardsDiagnosisEmptyDetail,
      recommendedAction: StoryboardListRecommendedAction.addStoryboard,
    );
  }

  final readyPromptCount = rows
      .where((row) => (row.prompt ?? '').trim().isNotEmpty)
      .length;
  if (!productionSummaryLoaded) {
    return StoryboardListDiagnosis(
      summary: l10n.scriptEditorStoryboardsDiagnosisProductionNotSyncedSummary(
        rows.length,
      ),
      detail: l10n.scriptEditorStoryboardsDiagnosisProductionNotSyncedDetail,
      recommendedAction:
          StoryboardListRecommendedAction.refreshProductionSummary,
    );
  }

  if (readyPromptCount == 0) {
    return StoryboardListDiagnosis(
      summary: l10n.scriptEditorStoryboardsDiagnosisNoPromptsSummary(
        rows.length,
      ),
      detail: l10n.scriptEditorStoryboardsDiagnosisNoPromptsDetail,
      recommendedAction: StoryboardListRecommendedAction.editStoryboard,
    );
  }

  return StoryboardListDiagnosis(
    summary: l10n.scriptEditorStoryboardsDiagnosisReadyBatchSummary(
      readyPromptCount,
      rows.length,
    ),
    detail: l10n.scriptEditorStoryboardsDiagnosisReadyBatchDetail,
    recommendedAction: StoryboardListRecommendedAction.openBatchWorkbench,
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
          productionStoryboard: productionById[row.numericId],
        ) !=
        null;
  }).length;

  if (selected.isEmpty) {
    if (readyAcrossAll > 0) {
      return StoryboardBatchWorkbenchDiagnosis(
        summary: '当前还没有选择要处理的分镜。',
        detail: '已有 $readyAcrossAll 条分镜具备可用提示词，可直接一键批量出图；系统会自动挑出准备好的分镜入队。',
        recommendedAction:
            StoryboardBatchWorkbenchRecommendedAction.generateSelected,
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
  for (final numericId in selected) {
    StoryboardRow? scriptRow;
    for (final row in boardRows) {
      if (row.numericId == numericId) {
        scriptRow = row;
        break;
      }
    }
    final productionRow = productionById[numericId];
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
  VideoBatchWritebackSummary? videoWritebackSummary,
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
  final canAutoFillSingleTrack =
      (selectedTrackId == null || selectedTrackId <= 0) &&
      knownTrackIds.length == 1;
  if ((selectedTrackId == null || selectedTrackId <= 0) &&
      !canAutoFillSingleTrack) {
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
      detail: '建议先生成默认视频提示词并确认时长；准备完成后可直接一键生成视频。',
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt,
    );
  }

  final storyboardVideos = storyboardScopedVideos(
    generatedVideos,
    scriptStoryboard.numericId,
  );
  final inFlightJobTotal =
      videoWritebackSummary?.inFlightGenerationJobCount ?? generatingJobs.length;
  if (inFlightJobTotal > 0) {
    final pending = videoWritebackSummary?.storyboardNumericIdsPendingWriteback
            .length ??
        0;
    final detailExtra = pending > 0
        ? ' 其中约 $pending 条分镜仍仅有进行中任务，尚未检测到片媒体回库。'
        : '';
    return StoryboardWorkbenchDiagnosis(
      summary: '当前剧本还有 $inFlightJobTotal 条视频任务在运行。',
      detail: storyboardVideos.isEmpty
          ? '建议先刷新视频数据，确认当前分镜是否已有新结果，再决定是否继续提交。$detailExtra'
          : '建议先刷新视频数据并检查当前分镜已有候选视频，再决定是否继续提交。$detailExtra',
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
    detail: '可以直接一键生成视频，系统会自动补齐生成前提示词刷新、建议裁剪和结果回刷。',
    recommendedAction:
        StoryboardWorkbenchRecommendedAction.submitVideoGeneration,
  );
}
