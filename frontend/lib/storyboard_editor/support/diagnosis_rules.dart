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

StoryboardBatchWorkbenchDiagnosis diagnoseStoryboardBatchWorkbench(
  AppLocalizations l10n, {
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
        summary: l10n.scriptEditorStoryboardBatchDiagnosisNoSelectionSummary,
        detail: l10n.scriptEditorStoryboardBatchDiagnosisNoSelectionWithReadyDetail(
          readyAcrossAll,
        ),
        recommendedAction:
            StoryboardBatchWorkbenchRecommendedAction.generateSelected,
      );
    }
    return StoryboardBatchWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardBatchDiagnosisNoSelectionSummary,
      detail: l10n.scriptEditorStoryboardBatchDiagnosisNoSelectionSyncFirstDetail,
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
      summary: l10n.scriptEditorStoryboardBatchDiagnosisPartialProductionSummary(
        selected.length,
      ),
      detail: l10n.scriptEditorStoryboardBatchDiagnosisPartialProductionDetail,
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
    );
  }

  if (selectedReadyCount == 0) {
    return StoryboardBatchWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardBatchDiagnosisNoPromptsSummary,
      detail: l10n.scriptEditorStoryboardBatchDiagnosisNoPromptsDetail,
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
    );
  }

  if (selectedWithImageCount == selected.length) {
    if (selected.length == 1) {
      return StoryboardBatchWorkbenchDiagnosis(
        summary: l10n.scriptEditorStoryboardBatchDiagnosisSingleHasImageSummary,
        detail: l10n.scriptEditorStoryboardBatchDiagnosisSingleHasImageDetail,
        recommendedAction:
            StoryboardBatchWorkbenchRecommendedAction.previewSelected,
      );
    }
    return StoryboardBatchWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardBatchDiagnosisAllHaveImagesSummary(
        selected.length,
      ),
      detail: l10n.scriptEditorStoryboardBatchDiagnosisAllHaveImagesDetail,
      recommendedAction:
          StoryboardBatchWorkbenchRecommendedAction.exportSelected,
    );
  }

  return StoryboardBatchWorkbenchDiagnosis(
    summary: l10n.scriptEditorStoryboardBatchDiagnosisMixedReadySummary(
      selected.length,
      selectedReadyCount,
    ),
    detail: l10n.scriptEditorStoryboardBatchDiagnosisMixedReadyDetail,
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
