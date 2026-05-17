import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';
import 'view.dart';

/// Maps short-video quality stage codes to localized labels (for tests and pure logic).
String shortVideoQualityStageLabel(AppLocalizations l10n, String stage) {
  final s = stage.trim();
  switch (s) {
    case '':
      return l10n.shortVideoSpacePublishQualityStageUnlabeled;
    case 'story_skeleton':
      return l10n.shortVideoSpacePublishQualityStageStorySkeleton;
    case 'adaptation_strategy':
      return l10n.shortVideoSpacePublishQualityStageAdaptationStrategy;
    case 'director_planning':
      return l10n.shortVideoSpacePublishQualityStageDirectorPlanning;
    case 'storyboard_table':
      return l10n.shortVideoSpacePublishQualityStageStoryboardTable;
    case 'storyboard_panel':
      return l10n.shortVideoSpacePublishQualityStageStoryboardPanel;
    case 'video_prompt':
      return l10n.shortVideoSpacePublishQualityStageVideoPrompt;
    default:
      return s;
  }
}

/// Maps short-video-export-check machine code to localized labels (for tests and pure logic).
List<String> shortVideoExportGapFacetLabels(
  AppLocalizations l10n,
  ShortVideoExportCheckStoryboardGap gap,
) {
  final out = <String>[];
  if (gap.missingSelectedVideo) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetMissingVideo);
  }
  if (gap.missingSubtitle) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetMissingSubtitle);
  }
  if (gap.missingVoiceover) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetMissingVoiceover);
  }
  if (gap.durationAnomaly) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetDurationAnomaly);
  }
  return out;
}

List<ShortVideoExportCheckStoryboardGapUi> buildShortVideoExportStoryboardGapUi(
  AppLocalizations l10n,
  List<ShortVideoExportCheckStoryboardGap> gaps, {
  bool blockingOnly = false,
}) {
  final filtered = blockingOnly
      ? gaps.where((g) => g.hasBlocking).toList(growable: false)
      : gaps;
  return filtered
      .map((g) {
        final sbPart = g.sbIndex == null
            ? ''
            : l10n.shortVideoPublishExportCheckStoryboardIndexPart(g.sbIndex!);
        final title = l10n.shortVideoSpacePublishExportCheckStoryboardGapTitle(
          g.scriptNumericId,
          g.storyboardNumericId,
          sbPart,
        );
        final facets = shortVideoExportGapFacetLabels(l10n, g);
        final facetSummary = facets.isEmpty
            ? g.gapCodes.map((c) => shortVideoExportIssueLabel(l10n, c)).join(' · ')
            : facets.join(' · ');
        final codeLabels = g.gapCodes
            .map((c) => shortVideoExportIssueLabel(l10n, c))
            .toList(growable: false);
        return ShortVideoExportCheckStoryboardGapUi(
          title: title,
          facetSummary: facetSummary,
          hasBlocking: g.hasBlocking,
          codeLabels: codeLabels,
        );
      })
      .toList(growable: false);
}

String shortVideoExportIssueLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'candidate_pending':
      return l10n.shortVideoSpacePublishExportIssueCandidatePending;
    case 'missing_selected_media':
      return l10n.shortVideoSpacePublishExportIssueMissingSelectedMedia;
    case 'selected_media_not_video':
      return l10n.shortVideoSpacePublishExportIssueSelectedMediaNotVideo;
    case 'subtitle_placeholder':
      return l10n.shortVideoSpacePublishExportIssueSubtitlePlaceholder;
    case 'subtitle_empty':
      return l10n.shortVideoSpacePublishExportIssueSubtitleEmpty;
    case 'voiceover_failed':
      return l10n.shortVideoSpacePublishExportIssueVoiceoverFailed;
    case 'voiceover_audio_missing':
      return l10n.shortVideoSpacePublishExportIssueVoiceoverAudioMissing;
    case 'voiceover_not_ready':
      return l10n.shortVideoSpacePublishExportIssueVoiceoverNotReady;
    case 'duration_not_explicit':
      return l10n.shortVideoSpacePublishExportIssueDurationNotExplicit;
    case 'duration_not_set':
      return l10n.shortVideoSpacePublishExportIssueDurationNotSet;
    case 'duration_unparsable':
      return l10n.shortVideoSpacePublishExportIssueDurationUnparsable;
    case 'completion_uncertain':
      return l10n.shortVideoSpacePublishExportIssueCompletionUncertain;
    default:
      return code;
  }
}

String shortVideoQualityStageLabelZh(BuildContext context, String stage) {
  return shortVideoQualityStageLabel(
    resolveAppLocalizationsForErrors(context),
    stage,
  );
}

String shortVideoExportIssueLabelZh(BuildContext context, String code) {
  return shortVideoExportIssueLabel(
    resolveAppLocalizationsForErrors(context),
    code,
  );
}

int? _parseDurationSecondsLoose(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  final m = RegExp(r'^(\d{1,4})(?:\s*s)?$').firstMatch(normalized);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String formatDurationHHMMSS(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final secs = s % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

bool shortVideoPublishHasUsableData({
  required PublishPlatformMatrixResponse? matrix,
  required List<PublishDraftRow> drafts,
  required PublishPrepareCheckResponse? prepare,
  required List<PublishJobRow> jobs,
  required List<PublishPerformanceAlertRow> performanceAlerts,
  required List<PublishAttemptAuditRow> audits,
}) {
  return matrix != null ||
      drafts.isNotEmpty ||
      prepare != null ||
      jobs.isNotEmpty ||
      performanceAlerts.isNotEmpty ||
      audits.isNotEmpty;
}

bool shortVideoPublishInteractionsAllowed({
  required bool publishUnavailable,
  required bool hasUsableData,
}) {
  return !publishUnavailable || hasUsableData;
}

Set<String> shortVideoFilterExistingDraftIds(
  Set<String> selectedDraftIds,
  List<PublishDraftRow> drafts,
) {
  if (selectedDraftIds.isEmpty || drafts.isEmpty) {
    return drafts.isEmpty ? <String>{} : Set<String>.from(selectedDraftIds);
  }
  final existingIds = drafts.map((d) => d.id).toSet();
  return selectedDraftIds.where(existingIds.contains).toSet();
}

bool shortVideoShouldKeepMultiSelectMode({
  required bool multiSelectMode,
  required List<PublishDraftRow> drafts,
}) {
  return multiSelectMode && drafts.length > 1;
}

/// Space 成片装配卡：消费 GET .../short-video-assembly
ShortVideoAssemblyPanelUi buildShortVideoAssemblyPanelUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectShortVideoAssembly? assembly,
}) {
  if (!projectSelected) {
    return const ShortVideoAssemblyPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoAssemblyPanelUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoSpacePublishAssemblyLoadingHeadline,
      detail: l10n.shortVideoSpacePublishAssemblyLoadingDetail,
    );
  }
  if (assembly == null) {
    return ShortVideoAssemblyPanelUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoSpacePublishAssemblyUnavailableHeadline,
      detail: l10n.shortVideoSpacePublishAssemblyUnavailableDetail,
    );
  }
  final scripts = assembly.scripts;
  var totalShots = 0;
  for (final g in scripts) {
    totalShots += g.shots.length;
  }
  final d = assembly.projectDefaults;
  final eff = assembly.effectiveShortVideoDefaults;
  final defaultParts = <String>[
    (d.voiceProfile ?? '').trim().isEmpty
        ? l10n.shortVideoSpacePublishAssemblyVoiceProfileNotSet
        : l10n.shortVideoSpacePublishAssemblyVoiceProfile(
            d.voiceProfile!.trim(),
          ),
    (d.subtitleStyle ?? '').trim().isEmpty
        ? l10n.shortVideoSpacePublishAssemblySubtitleDefault
        : l10n.shortVideoSpacePublishAssemblySubtitle(d.subtitleStyle!.trim()),
    (d.bgmStrategy ?? '').trim().isEmpty
        ? l10n.shortVideoSpacePublishAssemblyBgmNotSpecified
        : l10n.shortVideoSpacePublishAssemblyBgm(d.bgmStrategy!.trim()),
  ];
  final scriptLines = <String>[];
  var shotsWithVideo = 0;
  var shotsWithSubtitle = 0;
  var shotsWithVoiceover = 0;
  var totalDurationSeconds = 0;
  var durationKnownShots = 0;
  for (final g in scripts) {
    final name = (g.scriptName ?? '').trim();
    final title = name.isEmpty
        ? l10n.shortVideoSpacePublishAssemblyScriptTitle(g.scriptNumericId)
        : l10n.shortVideoSpacePublishAssemblyScriptTitleNamed(
            g.scriptNumericId,
            name,
          );
    final shots = g.shots;
    final withMedia = shots
        .where((sh) => (sh.selectedMediaUrl ?? '').trim().isNotEmpty)
        .length;
    final voReady = shots.where((sh) => sh.voiceoverAssetReady).length;
    scriptLines.add(
      l10n.shortVideoSpacePublishAssemblyScriptSummary(
        title,
        shots.length,
        withMedia,
        voReady,
      ),
    );
    for (final sh in shots.take(4)) {
      final preview = (sh.selectedMediaUrl ?? '').trim().isNotEmpty
          ? l10n.shortVideoSpacePublishAssemblyShotPreviewYes
          : l10n.shortVideoSpacePublishAssemblyShotPreviewNo;
      final duration = (sh.duration ?? '').trim();
      final subtitle = (sh.subtitleText ?? '').trim();
      final subtitleState = subtitle.isEmpty
          ? l10n.shortVideoSpacePublishAssemblyShotSubtitleNo
          : l10n.shortVideoSpacePublishAssemblyShotSubtitleYes;
      final voiceover =
          sh.voiceoverAssetReady ||
              (sh.voiceoverAudioUrl ?? '').trim().isNotEmpty
          ? l10n.shortVideoSpacePublishAssemblyShotVoiceoverYes
          : l10n.shortVideoSpacePublishAssemblyShotVoiceoverNo;
      final order = sh.sbIndex?.toString() ?? '${sh.storyboardNumericId}';
      final bgm = (d.bgmStrategy ?? '').trim().isEmpty
          ? l10n.shortVideoSpacePublishAssemblyShotBgmDefault
          : d.bgmStrategy!.trim();
      scriptLines.add(
        l10n.shortVideoSpacePublishAssemblyShotDetail(
          order,
          preview,
          duration.isEmpty
              ? l10n.shortVideoSpacePublishAssemblyShotDurationUnknown
              : duration,
          subtitleState,
          voiceover,
          bgm,
        ),
      );
    }
    for (final sh in shots) {
      if ((sh.selectedMediaUrl ?? '').trim().isNotEmpty) {
        shotsWithVideo += 1;
      }
      if ((sh.subtitleText ?? '').trim().isNotEmpty) {
        shotsWithSubtitle += 1;
      }
      if (sh.voiceoverAssetReady ||
          (sh.voiceoverAudioUrl ?? '').trim().isNotEmpty) {
        shotsWithVoiceover += 1;
      }
      final sec = _parseDurationSecondsLoose(sh.duration ?? '');
      if (sec != null && sec > 0) {
        totalDurationSeconds += sec;
        durationKnownShots += 1;
      }
    }
    if (shots.length > 4) {
      scriptLines.add(
        l10n.shortVideoSpacePublishAssemblyMoreShots(shots.length - 4),
      );
    }
  }
  final q = assembly.candidateQualitySummary;
  final qualityLines = <String>[
    l10n.shortVideoSpacePublishAssemblyQualityProjectBadCase(
      q.projectBadCaseTotal,
    ),
    l10n.shortVideoSpacePublishAssemblyQualityAssemblyReviews(
      q.assemblyShotReviewTotal,
      q.assemblyShotBadCaseCount,
      q.assemblyShotsWithBadCase,
    ),
    l10n.shortVideoSpacePublishAssemblyQualityLateStageBadCase(
      q.assemblyLateStageBadCaseCount,
    ),
  ];
  final stageLines = q.badCasesByStage
      .take(6)
      .map(
        (b) => l10n.shortVideoSpacePublishAssemblyQualityStageBadCase(
          shortVideoQualityStageLabel(l10n, b.stage),
          b.badCaseCount,
        ),
      )
      .toList(growable: false);
  if (stageLines.isNotEmpty) {
    qualityLines.add(
      l10n.shortVideoSpacePublishAssemblyQualityByStage(stageLines.join('；')),
    );
  }
  qualityLines.add(l10n.shortVideoSpacePublishAssemblyQualityTaskCenterHint);

  final hasBgm = (d.bgmStrategy ?? '').trim().isNotEmpty;
  final multiTrackTrackCount =
      1 +
      (shotsWithSubtitle > 0 ? 1 : 0) +
      (shotsWithVoiceover > 0 ? 1 : 0) +
      (hasBgm ? 1 : 0);
  final withinLimitedTracks = multiTrackTrackCount <= 4;
  final timelineMinutes = totalDurationSeconds / 60.0;
  final overProfessionalBoundary =
      !withinLimitedTracks || timelineMinutes > 8.0;

  final totalDurationFormatted = formatDurationHHMMSS(totalDurationSeconds);
  final headlineWithDuration = scripts.isEmpty
      ? l10n.shortVideoSpacePublishAssemblyNoScriptsHeadline
      : l10n.shortVideoSpacePublishAssemblyHeadlineScripts(
          scripts.length,
          totalShots,
          totalDurationSeconds,
          totalDurationFormatted,
        );

  final multiTrackDecisionLines = <String>[
    l10n.shortVideoSpacePublishAssemblyMultiTrackEstimate(
      shotsWithSubtitle > 0 ? 1 : 0,
      shotsWithVoiceover > 0 ? 1 : 0,
      hasBgm ? 1 : 0,
      multiTrackTrackCount,
    ),
    l10n.shortVideoSpacePublishAssemblyMaterialReady(
      shotsWithVideo,
      shotsWithSubtitle,
      shotsWithVoiceover,
      totalShots,
    ),
    l10n.shortVideoSpacePublishAssemblyDurationEstimate(
      durationKnownShots,
      totalShots,
      timelineMinutes.toStringAsFixed(1),
    ),
    if (overProfessionalBoundary)
      l10n.shortVideoSpacePublishAssemblyExportDecisionProfessional
    else
      l10n.shortVideoSpacePublishAssemblyExportDecisionLimited,
    l10n.shortVideoSpacePublishAssemblyBoundaryNote,
  ];
  return ShortVideoAssemblyPanelUi(
    visible: true,
    headline: headlineWithDuration,
    defaultsLine:
        '${defaultParts.join(' · ')}\n${l10n.shortVideoSpacePublishAssemblyEffectiveTts(eff.ttsVoice)}',
    qualityLines: qualityLines,
    scriptLines: scriptLines,
    multiTrackDecisionLines: multiTrackDecisionLines,
    detail: l10n.shortVideoSpacePublishAssemblyDetail,
  );
}

/// Space 导出前检查卡：消费 GET .../short-video-export-check
ShortVideoExportCheckPanelUi buildShortVideoExportCheckPanelUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectShortVideoExportCheck? exportCheck,
}) {
  if (!projectSelected) {
    return const ShortVideoExportCheckPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoExportCheckPanelUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoSpacePublishExportCheckLoadingHeadline,
      detail: l10n.shortVideoSpacePublishExportCheckLoadingDetail,
    );
  }
  if (exportCheck == null) {
    return ShortVideoExportCheckPanelUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoSpacePublishExportCheckUnavailableHeadline,
      detail: l10n.shortVideoSpacePublishExportCheckUnavailableDetail,
    );
  }
  final s = exportCheck.summary;
  final metrics = <ShortVideoMetricData>[
    ShortVideoMetricData(
      label: l10n.shortVideoSpacePublishExportCheckMetricStoryboards,
      value: '${s.storyboardCount}',
    ),
    ShortVideoMetricData(
      label: l10n.shortVideoSpacePublishExportCheckMetricBlocking,
      value: '${s.blockingIssueCount}',
    ),
    ShortVideoMetricData(
      label: l10n.shortVideoSpacePublishExportCheckMetricWarning,
      value: '${s.warningIssueCount}',
    ),
    ShortVideoMetricData(
      label: l10n.shortVideoSpacePublishExportCheckMetricExportable,
      value: exportCheck.exportReady
          ? l10n.shortVideoSpacePublishExportCheckMetricYes
          : l10n.shortVideoSpacePublishExportCheckMetricNo,
    ),
  ];
  final headline = exportCheck.exportReady
      ? l10n.shortVideoSpacePublishExportCheckReadyHeadline
      : l10n.shortVideoSpacePublishExportCheckBlockingHeadline;
  final qg = exportCheck.qualityGate;

  // Build quality gate line based on strategy
  String qualityGateLine;
  if (qg.strategy == 'off') {
    qualityGateLine = l10n.shortVideoSpacePublishExportCheckQualityGateOff;
  } else if (qg.strategy == 'warn') {
    if (qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = l10n
          .shortVideoSpacePublishExportCheckQualityGateWarnWithBadCase(
            qg.pendingReviewBadCaseCount,
          );
    } else {
      qualityGateLine =
          l10n.shortVideoSpacePublishExportCheckQualityGateWarnNoBadCase;
    }
  } else if (qg.strategy == 'block') {
    if (qg.enforced && qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = l10n
          .shortVideoSpacePublishExportCheckQualityGateBlockEnforcedWithBadCase(
            qg.pendingReviewBadCaseCount,
          );
    } else if (qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = l10n
          .shortVideoSpacePublishExportCheckQualityGateBlockNotEnforcedWithBadCase(
            qg.pendingReviewBadCaseCount,
          );
    } else {
      qualityGateLine =
          l10n.shortVideoSpacePublishExportCheckQualityGateBlockNoBadCase;
    }
  } else {
    qualityGateLine = l10n.shortVideoSpacePublishExportCheckQualityGateUnknown(
      qg.strategy,
    );
  }

  // Collect blocking reasons if in block mode
  final qualityGateBlockingLines = <String>[];
  if (qg.strategy == 'block' && qg.enforced && qg.blockingReasons != null) {
    for (final reason in qg.blockingReasons!) {
      final routePart = reason.reworkRoute != null
          ? l10n.shortVideoPublishExportCheckReworkRouteSuffix(
              reason.reworkRoute!,
            )
          : '';
      qualityGateBlockingLines.add(
        l10n.shortVideoPublishExportCheckQualityGateBlockingLine(
          reason.code.trim().toUpperCase(),
          reason.message,
          routePart,
        ),
      );
    }
  }
  final storyboardGapEntries = exportCheck.storyboardGaps.isNotEmpty
      ? buildShortVideoExportStoryboardGapUi(
          l10n,
          exportCheck.storyboardGaps,
          blockingOnly: true,
        )
      : const <ShortVideoExportCheckStoryboardGapUi>[];
  final blockingLines = exportCheck.issues
      .where((i) => i.severity == 'blocking')
      .take(14)
      .map((i) {
        final sb = i.sbIndex;
        final sbPart = sb == null
            ? ''
            : l10n.shortVideoPublishExportCheckStoryboardIndexPart(sb);
        return l10n.shortVideoSpacePublishExportCheckBlockingIssue(
          i.scriptNumericId,
          i.storyboardNumericId,
          sbPart,
          shortVideoExportIssueLabel(l10n, i.code),
          i.detail,
        );
      })
      .toList(growable: false);
  final warningLines = exportCheck.issues
      .where((i) => i.severity == 'warning')
      .take(14)
      .map((i) {
        final sb = i.sbIndex;
        final sbPart = sb == null
            ? ''
            : l10n.shortVideoPublishExportCheckStoryboardIndexPart(sb);
        return l10n.shortVideoSpacePublishExportCheckBlockingIssue(
          i.scriptNumericId,
          i.storyboardNumericId,
          sbPart,
          shortVideoExportIssueLabel(l10n, i.code),
          i.detail,
        );
      })
      .toList(growable: false);
  final detail = exportCheck.exportReady
      ? l10n.shortVideoSpacePublishExportCheckDetailReady
      : l10n.shortVideoSpacePublishExportCheckDetailBlocking;
  return ShortVideoExportCheckPanelUi(
    visible: true,
    headline: headline,
    metrics: metrics,
    qualityGateLine: qualityGateLine,
    qualityGateBlockingLines: qualityGateBlockingLines,
    storyboardGapEntries: storyboardGapEntries,
    blockingLines: storyboardGapEntries.isEmpty ? blockingLines : const <String>[],
    warningLines: warningLines,
    detail: detail,
    exportReady: exportCheck.exportReady,
  );
}

/// Space 候选资产确认卡：消费 GET .../assets-overview 的 candidate_counts
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
