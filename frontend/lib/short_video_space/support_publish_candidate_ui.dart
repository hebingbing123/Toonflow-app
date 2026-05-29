part of 'support_publish_api.dart';

ShortVideoCandidateCardUi buildShortVideoCandidateCardUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectAssetsOverview? assetsOverview,
  VoidCallback? onBatchGenerateCandidateClips,
  bool batchGenerateCandidateClipsBusy = false,
  VoidCallback? onConfirmStoryboardCandidates,
  bool confirmStoryboardCandidatesBusy = false,
  int candidatePendingStoryboardCount = 0,
}) {
  if (!projectSelected) {
    return const ShortVideoCandidateCardUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoCandidateCardUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoSpacePublishCandidateLoadingHeadline,
      detail: l10n.shortVideoSpacePublishCandidateLoadingDetail,
    );
  }
  if (assetsOverview == null) {
    return ShortVideoCandidateCardUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoSpacePublishCandidateUnavailableHeadline,
      detail: l10n.shortVideoSpacePublishCandidateUnavailableDetail,
    );
  }
  final c = assetsOverview.candidateCounts;
  final pending = c.pending;
  final linked = c.linked;
  final ignored = c.ignored;
  final unset = c.unset;
  final tracked = pending + linked + ignored;
  final headline = tracked == 0
      ? l10n.shortVideoSpacePublishCandidateNoTrackedHeadline
      : l10n.shortVideoSpacePublishCandidateTrackedHeadline;
  final detail = l10n.shortVideoSpacePublishCandidateDetail(
    assetsOverview.totalCount,
  );
  return ShortVideoCandidateCardUi(
    visible: true,
    pending: pending,
    linked: linked,
    ignored: ignored,
    unset: unset,
    headline: headline,
    detail: detail,
    onBatchGenerateCandidateClips: onBatchGenerateCandidateClips,
    batchGenerateCandidateClipsBusy: batchGenerateCandidateClipsBusy,
    onConfirmStoryboardCandidates: candidatePendingStoryboardCount > 0
        ? onConfirmStoryboardCandidates
        : null,
    confirmStoryboardCandidatesBusy: confirmStoryboardCandidatesBusy,
  );
}

/// E10–E13：消费 GET /publish/*，编排发布清单 / 矩阵 / 草稿 / 作业
ShortVideoPublishPanelUi buildShortVideoPublishPanelUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required bool publishUnavailable,
  required ProjectShortVideoExportCheck? exportCheck,
  required PublishPlatformMatrixResponse? matrix,
  required List<PublishDraftRow> drafts,
  required PublishPrepareCheckResponse? prepare,
  required List<PublishJobRow> jobs,
  required List<PublishPerformanceAlertRow> performanceAlerts,
  required List<PublishAttemptAuditRow> audits,
  required String? selectedPublishDraftId,
  ValueChanged<String>? onSelectPublishDraft,
  required bool publishBusy,
  VoidCallback? onRefreshPublish,
  VoidCallback? onBootstrapPublishDraft,
  VoidCallback? onEnqueuePublishJob,
  VoidCallback? onEnqueueAllDrafts,
  VoidCallback? onRetryFailedPublishJobs,
  VoidCallback? onConfirmSemiAuto,
  VoidCallback? onSuggestPublishCopy,
  VoidCallback? onClearPublishSchedule,
  VoidCallback? onOpenPublishTroubleshooting,
  List<String> publishTargetPlatformIds = const [],
  Map<String, String> publishAutomationModesByPlatform =
      const <String, String>{},
  void Function(String platformId, String automationMode)?
  onChangePublishAutomationMode,
  List<String> publishBatchResultLines = const <String>[],
  int publishCopyEditorRevision = 0,
  PublishPlatformCopyCommit? onCommitPublishPlatformCopy,
  void Function(BuildContext context)? onScheduleFirstDraft,
  void Function(BuildContext context)? onScheduleAllDraftsSameTime,
  PublishCalendarDayCallback? onPublishCalendarDayBulkSchedule,
  // P8: Multi-select parameters
  bool multiSelectMode = false,
  Set<String> selectedDraftIds = const <String>{},
  VoidCallback? onToggleMultiSelectMode,
  ValueChanged<String>? onToggleDraftSelection,
  VoidCallback? onSelectAllDrafts,
  VoidCallback? onClearDraftSelection,
  void Function(BuildContext context)? onBatchScheduleDrafts,
  VoidCallback? onBatchPublishDrafts,
  VoidCallback? onBatchArchiveDrafts,
  VoidCallback? onCompareDrafts,
  PublishBatchValidationResponse? batchValidation,
  void Function(BuildContext context)? onResetConfirmationDontShowAgain,
  // P11: Delivery mode parameters
  Map<String, int> jobsByDeliveryMode = const <String, int>{},
  String? deliveryModeFilter,
  ValueChanged<String>? onDeliveryModeFilterChanged,
}) {
  if (!projectSelected) {
    return const ShortVideoPublishPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoPublishPanelUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoSpacePublishPanelLoadingHeadline,
      detail: l10n.shortVideoSpacePublishPanelLoadingDetail,
    );
  }
  final hasPublishSliceData = shortVideoPublishHasUsableData(
    matrix: matrix,
    drafts: drafts,
    prepare: prepare,
    jobs: jobs,
    performanceAlerts: performanceAlerts,
    audits: audits,
  );
  final renderUnavailableCard = publishUnavailable && !hasPublishSliceData;

  if (renderUnavailableCard) {
    return ShortVideoPublishPanelUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoSpacePublishPanelUnavailableHeadline,
      exportGateHint: exportCheck == null
          ? l10n.shortVideoSpacePublishPanelUnavailableExportGateMissing
          : (exportCheck.summary.blockingIssueCount <= 0
                ? l10n.shortVideoSpacePublishPanelUnavailableExportGateNoBlocking
                : l10n.shortVideoSpacePublishPanelUnavailableExportGateBlocking(
                    exportCheck.summary.blockingIssueCount,
                  )),
      exportReady: exportCheck?.exportReady ?? false,
      detail: l10n.shortVideoSpacePublishPanelUnavailableDetail,
      onRefreshPublish: onRefreshPublish,
      publishBusy: publishBusy,
      onResetConfirmationDontShowAgain: onResetConfirmationDontShowAgain,
    );
  }

  final gate = exportCheck == null
      ? l10n.shortVideoSpacePublishPanelExportGateUnavailable
      : (exportCheck.summary.blockingIssueCount <= 0
            ? l10n.shortVideoSpacePublishPanelExportGateReady
            : l10n.shortVideoSpacePublishPanelExportGateBlocking(
                exportCheck.summary.blockingIssueCount,
              ));

  final exportReadyStatus = exportCheck?.exportReady ?? false;

  final matrixDomesticLines = <String>[];
  final matrixOverseasLines = <String>[];
  if (matrix != null) {
    for (final row in matrix.platforms) {
      final line =
          l10n.shortVideoPublishMatrixPlatformRow(
            row.labelZh,
            row.platformId,
            shortVideoPublishAutomationModeLabel(l10n, row.automationMode),
            row.titleMaxChars,
            row.tagsMax,
            row.descriptionMaxChars,
          ) +
          (row.requiresCover
              ? l10n.shortVideoPublishMatrixRequiresCoverSuffix
              : '');
      if (row.marketRegion == 'overseas') {
        matrixOverseasLines.add(line);
      } else {
        matrixDomesticLines.add(line);
      }
    }
  }

  String? activeDraftId = selectedPublishDraftId;
  final selectedOk =
      activeDraftId != null &&
      activeDraftId.trim().isNotEmpty &&
      drafts.any((d) => d.id == activeDraftId);
  if (!selectedOk) {
    activeDraftId = drafts.length == 1 ? drafts.first.id : null;
  }
  PublishDraftRow? activeDraft;
  if (activeDraftId != null) {
    for (final d in drafts) {
      if (d.id == activeDraftId) {
        activeDraft = d;
        break;
      }
    }
  }

  final prepareLines = <String>[
    if (activeDraft != null)
      l10n.shortVideoSpacePublishPanelCurrentDraft(
        activeDraft.title.trim().isEmpty
            ? l10n.shortVideoSpacePublishPanelDraftNoTitle
            : activeDraft.title.trim(),
      )
    else if (drafts.isNotEmpty)
      l10n.shortVideoSpacePublishPanelSelectDraftWarning,
    if (activeDraft != null && prepare != null) ...[
      if (prepare.ok) l10n.shortVideoSpacePublishPanelPrepareCheckOk,
      for (final issue in prepare.issues)
        '${shortVideoPublishPrepareSeverityLabel(l10n, issue.severity)}: ${issue.message}'
            '${issue.platformId != null ? ' · ${issue.platformId}' : ''}',
    ] else if (activeDraft != null)
      l10n.shortVideoSpacePublishPanelPrepareCheckSelectFirst
    else if (activeDraft == null && drafts.length > 1)
      l10n.shortVideoSpacePublishPanelPrepareCheckMultipleDrafts
    else if (activeDraft == null && drafts.isNotEmpty)
      l10n.shortVideoSpacePublishPanelPrepareCheckSelectFirst
    else
      l10n.shortVideoSpacePublishPanelPrepareCheckNoDraft,
  ];

  final draftLines = drafts
      .map((d) {
        final title = d.title.trim().isEmpty
            ? l10n.shortVideoSpacePublishPanelDraftNoTitle
            : d.title.trim();
        final videoMissing = (d.videoAssetKey ?? '').trim().isEmpty
            ? l10n.shortVideoSpacePublishPanelDraftMissingVideo
            : '';
        final scheduled = (d.scheduledAt ?? '').trim().isEmpty
            ? ''
            : l10n.shortVideoSpacePublishPanelDraftScheduled(d.scheduledAt!);
        final statusLabel = shortVideoPublishDraftStatusLabel(
          l10n,
          d.draftStatus,
        );
        return '$title · $statusLabel$videoMissing$scheduled';
      })
      .toList(growable: false);

  final jobLines = jobs
      .map((j) {
        final short = j.id.length > 8
            ? l10n.shortVideoSpacePublishPanelJobShortId(j.id.substring(0, 8))
            : j.id;
        final err = (j.errorMessage ?? '').trim();
        final errPart = err.isEmpty
            ? ''
            : l10n.shortVideoSpacePublishPanelJobError(err);
        final statusLabel = shortVideoPublishJobStatusLabel(l10n, j.status);
        return '$short · $statusLabel$errPart';
      })
      .toList(growable: false);
  final succeededJobCount = jobs.where((j) => j.status == 'succeeded').length;
  final failedJobCount = jobs
      .where((j) => j.status == 'failed' || j.status == 'partial_failed')
      .length;
  final waitingConfirmCount = jobs
      .where((j) => j.status == 'awaiting_confirmation')
      .length;
  final scheduledDraftCount = drafts
      .where((d) => (d.scheduledAt ?? '').trim().isNotEmpty)
      .length;
  final labels = <String, String>{
    for (final id in kShortVideoPublishPlatformIdsInDisplayOrder)
      id: shortVideoPublishPlatformLabel(l10n, id),
  };
  if (matrix != null) {
    for (final p in matrix.platforms) {
      labels[p.platformId] = shortVideoPublishPlatformLabelWithMatrixFallback(
        l10n,
        p.platformId,
        p.labelZh,
      );
    }
  }

  final publishOverviewLines = <String>[
    '${l10n.shortVideoSpacePublishPanelOverviewSucceeded(succeededJobCount)} · ${l10n.shortVideoSpacePublishPanelOverviewFailed(failedJobCount)}',
    '${l10n.shortVideoSpacePublishPanelOverviewAwaiting(waitingConfirmCount)} · ${l10n.shortVideoSpacePublishPanelOverviewScheduled(scheduledDraftCount, drafts.length)}',
    if (audits.isNotEmpty)
      l10n.shortVideoSpacePublishPanelOverviewDeliveryModes(
        audits
            .take(8)
            .map((a) => a.deliveryMode)
            .toSet()
            .map((m) => shortVideoDeliveryModeLabel(l10n, m))
            .join(" / "),
      ),
    if (performanceAlerts.isNotEmpty)
      l10n.shortVideoSpacePublishPanelOverviewPerformanceAlerts(
        performanceAlerts.length,
      ),
    ...performanceAlerts
        .take(3)
        .map(
          (a) => l10n.shortVideoSpacePublishPanelOverviewPerformanceAlert(
            shortVideoPublishPlatformLabel(l10n, a.platformId),
            a.views,
            (a.completionRate * 100).toStringAsFixed(0),
          ),
        ),
    ...audits.take(3).map((a) {
      final p = shortVideoPublishPlatformLabel(l10n, a.platformId);
      return l10n.shortVideoSpacePublishPanelOverviewAudit(
        p,
        shortVideoPublishJobStatusLabel(l10n, a.status),
        shortVideoDeliveryModeLabel(l10n, a.deliveryMode),
      );
    }),
    if (publishAutomationModesByPlatform.isNotEmpty)
      l10n.shortVideoSpacePublishPanelOverviewTargetAutomation(
        publishAutomationModesByPlatform.entries
            .map(
              (e) =>
                  "${labels[e.key] ?? e.key}=${shortVideoPublishAutomationModeLabel(l10n, e.value)}",
            )
            .join("；"),
      ),
  ];

  String? awaitingId;
  for (final j in jobs) {
    if (j.status == 'awaiting_confirmation') {
      awaitingId = j.id;
      break;
    }
  }

  final domesticTargetIds = <String>[];
  final overseasTargetIds = <String>[];
  if (matrix != null && publishTargetPlatformIds.isNotEmpty) {
    final domesticSet = matrix.platforms
        .where((p) => p.marketRegion != 'overseas')
        .map((p) => p.platformId)
        .toSet();
    final overseasSet = matrix.platforms
        .where((p) => p.marketRegion == 'overseas')
        .map((p) => p.platformId)
        .toSet();
    for (final id in publishTargetPlatformIds) {
      if (domesticSet.contains(id)) {
        domesticTargetIds.add(id);
      } else if (overseasSet.contains(id)) {
        overseasTargetIds.add(id);
      } else {
        domesticTargetIds.add(id);
      }
    }
  }

  final primaryDraftId = activeDraft?.id ?? '';
  final platformCopySnap = activeDraft != null
      ? Map<String, dynamic>.from(activeDraft.platformCopy ?? {})
      : <String, dynamic>{};

  final jobsByDeliveryModeMap = <String, int>{};
  for (final job in jobs) {
    final mode = job.deliveryMode ?? 'unknown';
    jobsByDeliveryModeMap[mode] = (jobsByDeliveryModeMap[mode] ?? 0) + 1;
  }

  final detail = publishUnavailable
      ? '${l10n.shortVideoSpacePublishPanelDetail} ${l10n.shortVideoSpacePublishPanelUnavailableDetail}'
      : l10n.shortVideoSpacePublishPanelDetail;

  return ShortVideoPublishPanelUi(
    visible: true,
    headline: l10n.shortVideoSpacePublishPanelHeadline(
      drafts.length,
      jobs.length,
    ),
    exportGateHint: gate,
    exportReady: exportReadyStatus,
    matrixDomesticLines: matrixDomesticLines,
    matrixOverseasLines: matrixOverseasLines,
    prepareLines: prepareLines,
    draftLines: draftLines,
    jobLines: jobLines,
    publishOverviewLines: publishOverviewLines,
    detail: detail,
    onRefreshPublish: onRefreshPublish,
    publishBusy: publishBusy,
    onBootstrapPublishDraft: onBootstrapPublishDraft,
    onEnqueuePublishJob: onEnqueuePublishJob,
    awaitingSemiAutoJobId: awaitingId,
    onConfirmSemiAuto: awaitingId != null ? onConfirmSemiAuto : null,
    onSuggestPublishCopy: onSuggestPublishCopy,
    onClearPublishSchedule: onClearPublishSchedule,
    publishPrimaryDraftId: primaryDraftId,
    publishDomesticTargetIds: domesticTargetIds,
    publishOverseasTargetIds: overseasTargetIds,
    publishPlatformLabels: labels,
    publishPlatformCopySnapshot: platformCopySnap,
    publishCopyEditorRevision: publishCopyEditorRevision,
    onCommitPublishPlatformCopy: onCommitPublishPlatformCopy,
    onScheduleFirstDraft: onScheduleFirstDraft,
    onScheduleAllDraftsSameTime: onScheduleAllDraftsSameTime,
    onEnqueueAllDrafts: onEnqueueAllDrafts,
    onRetryFailedPublishJobs: onRetryFailedPublishJobs,
    publishBatchResultLines: publishBatchResultLines,
    publishAutomationModesByPlatform: publishAutomationModesByPlatform,
    onChangePublishAutomationMode: onChangePublishAutomationMode,
    publishDraftOptions: drafts,
    selectedPublishDraftId: activeDraftId,
    onSelectPublishDraft: onSelectPublishDraft,
    publishScheduleCalendarDrafts: drafts.isEmpty ? null : drafts,
    onPublishCalendarDayBulkSchedule: drafts.isEmpty
        ? null
        : onPublishCalendarDayBulkSchedule,
    onOpenPublishTroubleshooting: onOpenPublishTroubleshooting,
    multiSelectMode: multiSelectMode,
    selectedDraftIds: selectedDraftIds,
    onToggleMultiSelectMode: onToggleMultiSelectMode,
    onToggleDraftSelection: onToggleDraftSelection,
    onSelectAllDrafts: onSelectAllDrafts,
    onClearDraftSelection: onClearDraftSelection,
    onBatchScheduleDrafts: onBatchScheduleDrafts,
    onBatchPublishDrafts: onBatchPublishDrafts,
    onBatchArchiveDrafts: onBatchArchiveDrafts,
    onCompareDrafts: onCompareDrafts,
    batchValidation: batchValidation,
    onResetConfirmationDontShowAgain: onResetConfirmationDontShowAgain,
    jobsByDeliveryMode: jobsByDeliveryModeMap,
    deliveryModeFilter: deliveryModeFilter,
    onDeliveryModeFilterChanged: onDeliveryModeFilterChanged,
  );
}
