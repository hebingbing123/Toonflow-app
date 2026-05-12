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

StoryboardWorkbenchDiagnosis diagnoseStoryboardWorkbench(
  AppLocalizations l10n, {
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
    return StoryboardWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardsVideoDiagnosisNeedProductionSummary,
      detail: l10n.scriptEditorStoryboardsVideoDiagnosisNeedProductionDetail,
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.syncProductionData,
    );
  }

  final sourceImage = resolveStoryboardSourceImageUrl(
    productionStoryboard: productionStoryboard,
    draftImageUrl: draftImageUrl,
  );
  if (sourceImage == null) {
    return StoryboardWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardsVideoDiagnosisNoFrameSummary,
      detail: l10n.scriptEditorStoryboardsVideoDiagnosisNoFrameDetail,
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
      summary: knownTrackIds.isEmpty
          ? l10n.scriptEditorStoryboardsVideoDiagnosisNoTracksSummary
          : l10n.scriptEditorStoryboardsVideoDiagnosisNoTrackSelectedSummary,
      detail: knownTrackIds.isEmpty
          ? l10n.scriptEditorStoryboardsVideoDiagnosisNoTracksDetail
          : l10n.scriptEditorStoryboardsVideoDiagnosisPickTrackDetail(
              knownTrackIds.join(', '),
            ),
      recommendedAction: StoryboardWorkbenchRecommendedAction.prepareVideoTrack,
    );
  }

  final prompt = videoPromptText.trim();
  final duration = int.tryParse(videoDurationText.trim());
  if (prompt.isEmpty || duration == null || duration <= 0) {
    return StoryboardWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsSummary,
      detail: l10n.scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsDetail,
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
    final suffix = pending > 0
        ? l10n.scriptEditorStoryboardsVideoDiagnosisJobsPendingSuffix(pending)
        : '';
    return StoryboardWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardsVideoDiagnosisJobsRunningSummary(
        inFlightJobTotal,
      ),
      detail: storyboardVideos.isEmpty
          ? l10n.scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailNoVideos(
              suffix,
            )
          : l10n.scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailHasVideos(
              suffix,
            ),
      recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
    );
  }

  if (storyboardVideos.isNotEmpty) {
    return StoryboardWorkbenchDiagnosis(
      summary: l10n.scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesSummary(
        storyboardVideos.length,
      ),
      detail: l10n.scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesDetail,
      recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
    );
  }

  return StoryboardWorkbenchDiagnosis(
    summary: l10n.scriptEditorStoryboardsVideoDiagnosisAllReadySummary,
    detail: l10n.scriptEditorStoryboardsVideoDiagnosisAllReadyDetail,
    recommendedAction:
        StoryboardWorkbenchRecommendedAction.submitVideoGeneration,
  );
}
