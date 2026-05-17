import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../l10n/short_video_readiness_localized.dart';
import '../rust_api.dart';
import 'support_project_api.dart';
import 'view.dart';

String? formatShortVideoWritebackLine(
  AppLocalizations l10n,
  StoryboardLastWritebackSummaryV1? writeback,
) {
  if (writeback == null) {
    return null;
  }
  final code = (writeback.errorCode ?? '').trim();
  switch (writeback.status.trim()) {
    case 'ok':
      return l10n.shortVideoWritebackStatusOk;
    case 'failed':
      return code.isEmpty
          ? l10n.shortVideoWritebackStatusFailedGeneric
          : l10n.shortVideoWritebackStatusFailed(code);
    case 'incomplete':
      return code.isEmpty
          ? l10n.shortVideoWritebackStatusIncompleteGeneric
          : l10n.shortVideoWritebackStatusIncomplete(code);
    default:
      return l10n.shortVideoWritebackStatusUnknown(writeback.status);
  }
}

String shortVideoQualitySummaryLine(
  AppLocalizations l10n, {
  required bool isAnimated,
  required QualityScopeInsightRow? insight,
}) {
  if (insight == null) {
    return isAnimated
        ? l10n.shortVideoQualityNoSignalAnimated
        : l10n.shortVideoQualityNoSignalLive;
  }
  final passRate = insight.passRatePercent.toStringAsFixed(0);
  if (isAnimated) {
    return l10n.shortVideoQualityInsightAnimated(
      passRate,
      insight.badCaseCount,
    );
  }
  return l10n.shortVideoQualityInsightLive(passRate, insight.badCaseCount);
}

String shortVideoFormatBadCaseLabel(AppLocalizations l10n, BadCaseStatItem item) {
  final raw = (item.badCaseCategory ?? '').trim();
  if (raw.isEmpty) {
    return l10n.shortVideoBadCaseUncategorized;
  }
  return raw.replaceAll('_', ' ');
}

String shortVideoFormatTaskKind(AppLocalizations l10n, JobRow row) {
  final kind = row.kind.trim();
  if (kind.isEmpty) {
    return l10n.shortVideoTaskUnnamed;
  }
  return kind.replaceAll('.', ' / ');
}

String shortVideoFormatTaskStatus(AppLocalizations l10n, JobRow row) {
  return shortVideoPublishJobStatusLabel(l10n, row.status);
}

List<ShortVideoReadinessItem> buildShortVideoReadinessItems(
  AppLocalizations l10n, {
  required bool isAnimated,
  required ProjectRow? project,
  required ProjectStats? stats,
  required int sceneAssetCount,
  required int clipAssetCount,
}) {
  final hasVisualStyle = shortVideoHasVisualStyleSignal(project);
  final hasDirection = shortVideoHasDirectionSignal(project);
  final visualLabel = shortVideoVisualStyleLabel(project, l10n);
  final directionLabel = shortVideoDirectionLabel(project, l10n);
  final roleCount = stats?.roleCount ?? 0;
  final scriptCount = stats?.scriptCount ?? 0;
  final storyboardCount = stats?.storyboardCount ?? 0;
  if (isAnimated) {
    return <ShortVideoReadinessItem>[
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessLabelScriptBase,
        ready: scriptCount > 0,
        detail: scriptCount > 0
            ? l10n.shortVideoReadinessDetailScriptsHas(scriptCount)
            : l10n.shortVideoReadinessDetailScriptsMissing,
      ),
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessAnimLabelRoleAssets,
        ready: roleCount > 0,
        detail: roleCount > 0
            ? l10n.shortVideoReadinessDetailRolesHas(roleCount)
            : l10n.shortVideoReadinessDetailRolesMissingAnim,
      ),
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessLabelSceneAssets,
        ready: sceneAssetCount > 0,
        detail: sceneAssetCount > 0
            ? l10n.shortVideoReadinessDetailScenesHas(sceneAssetCount)
            : l10n.shortVideoReadinessDetailScenesMissingAnim,
      ),
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessAnimLabelVisualStyle,
        ready: hasVisualStyle,
        detail: hasVisualStyle
            ? l10n.shortVideoReadinessDetailVisualConfigured(
                visualLabel ?? l10n.shortVideoReadinessFallbackStylePack,
              )
            : l10n.shortVideoReadinessDetailVisualMissingAnim,
      ),
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessAnimLabelDirectorManual,
        ready: hasDirection,
        detail: hasDirection
            ? l10n.shortVideoReadinessDetailDirectorConfigured(
                directionLabel ?? l10n.shortVideoReadinessFallbackDirectorPack,
              )
            : l10n.shortVideoReadinessDetailDirectorMissingAnim,
      ),
      ShortVideoReadinessItem(
        label: l10n.shortVideoReadinessAnimLabelStoryboardBase,
        ready: storyboardCount > 0,
        detail: storyboardCount > 0
            ? l10n.shortVideoReadinessDetailStoryboardsHas(storyboardCount)
            : l10n.shortVideoReadinessDetailStoryboardsMissing,
      ),
    ];
  }
  return <ShortVideoReadinessItem>[
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLabelScriptBase,
      ready: scriptCount > 0,
      detail: scriptCount > 0
          ? l10n.shortVideoReadinessDetailScriptsHas(scriptCount)
          : l10n.shortVideoReadinessDetailScriptsMissing,
    ),
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLiveLabelRoleSetup,
      ready: roleCount > 0,
      detail: roleCount > 0
          ? l10n.shortVideoReadinessDetailRolesHas(roleCount)
          : l10n.shortVideoReadinessDetailRolesMissingLive,
    ),
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLabelSceneAssets,
      ready: sceneAssetCount > 0,
      detail: sceneAssetCount > 0
          ? l10n.shortVideoReadinessDetailScenesHas(sceneAssetCount)
          : l10n.shortVideoReadinessDetailScenesMissingLive,
    ),
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLiveLabelClipRefs,
      ready: clipAssetCount > 0,
      detail: clipAssetCount > 0
          ? l10n.shortVideoReadinessDetailClipsHas(clipAssetCount)
          : l10n.shortVideoReadinessDetailClipsMissing,
    ),
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLiveLabelVisualManual,
      ready: hasVisualStyle,
      detail: hasVisualStyle
          ? l10n.shortVideoReadinessDetailVisualConfigured(
              visualLabel ?? l10n.shortVideoReadinessFallbackLiveVisualPack,
            )
          : l10n.shortVideoReadinessDetailVisualMissingLive,
    ),
    ShortVideoReadinessItem(
      label: l10n.shortVideoReadinessLiveLabelPerformanceManual,
      ready: hasDirection,
      detail: hasDirection
          ? l10n.shortVideoReadinessDetailDirectorConfigured(
              directionLabel ?? l10n.shortVideoReadinessFallbackDirectorPack,
            )
          : l10n.shortVideoReadinessDetailPerformanceMissingLive,
    ),
  ];
}

String shortVideoReadinessGapSummary(
  AppLocalizations l10n, {
  required bool isAnimated,
  required List<ShortVideoReadinessItem> readinessItems,
}) {
  final missing = readinessItems.where((item) => !item.ready).toList();
  if (missing.isEmpty) {
    return isAnimated
        ? l10n.shortVideoReadinessGapAllReadyAnimated
        : l10n.shortVideoReadinessGapAllReadyLive;
  }
  final labels = missing.take(3).map((item) => item.label).join('、');
  final more = missing.length > 3
      ? l10n.shortVideoReadinessGapAndMore(missing.length)
      : '';
  return l10n.shortVideoReadinessGapMissing(labels, more);
}

/// Builds the Space panel for **`GET /api/v1/projects/{id}/short-video-readiness`**.
ShotReadinessUi buildShotReadinessUi({
  required AppLocalizations l10n,
  required bool loadingProjectOverview,
  required ProjectShortVideoReadiness? readiness,
  required bool readinessUnavailable,
}) {
  if (loadingProjectOverview) {
    return const ShotReadinessUi(loading: true);
  }
  if (readinessUnavailable) {
    return const ShotReadinessUi(unavailable: true);
  }
  if (readiness == null) {
    return ShotReadinessUi(
      headline: l10n.shortVideoReadinessNoPayloadHeadline,
    );
  }
  final roll = readiness.rollup;
  if (roll.totalStoryboards == 0) {
    return ShotReadinessUi(
      headline: l10n.shortVideoReadinessEmptyProjectHeadline,
    );
  }
  final headline = l10n.shortVideoReadinessRollupHeadline(
    roll.readyCount,
    roll.totalStoryboards,
    roll.blockedCount,
  );
  final reasonLines = readiness.rollup.byReason
      .map(
        (e) => l10n.shortVideoReadinessReasonRollupLine(
          labelShortVideoBlockingReasonLocalized(l10n, e.reason),
          e.storyboardCount,
        ),
      )
      .toList(growable: false);
  final shotDetailLines = readiness.storyboards
      .where((s) => !s.readyForGeneration)
      .take(5)
      .map((s) {
        final parts = s.blockingReasons
            .map((c) => labelShortVideoBlockingReasonLocalized(l10n, c))
            .join('、');
        final script = s.scriptNumericId;
        final idx = s.sbIndex;
        final prefix = l10n.shortVideoReadinessStoryboardDetailPrefix(
          s.storyboardNumericId,
        );
        final scriptSeg =
            script != null ? l10n.shortVideoReadinessScriptSuffix(script) : '';
        final slotSeg =
            idx != null ? l10n.shortVideoReadinessSlotSuffix(idx) : '';
        final lead = '$prefix$scriptSeg$slotSeg';
        return l10n.shortVideoReadinessBlockedShotDetail(lead, parts);
      })
      .toList(growable: false);
  return ShotReadinessUi(
    headline: headline,
    reasonLines: reasonLines,
    shotDetailLines: shotDetailLines,
  );
}

String shortVideoAssetTypeOverviewLabel(AppLocalizations l10n, String assetType) {
  switch (assetType) {
    case 'role':
      return l10n.shortVideoAssetTypeRole;
    case 'scene':
      return l10n.shortVideoAssetTypeScene;
    case 'tool':
      return l10n.shortVideoAssetTypeTool;
    case 'clip':
      return l10n.shortVideoAssetTypeClip;
    default:
      return assetType.isEmpty ? l10n.shortVideoAssetTypeOther : assetType;
  }
}

/// Space **统一资产总览**（C9）：消费 **`GET /projects/{id}/assets-overview`**。
ShortVideoAssetsOverviewPanelUi buildShortVideoAssetsOverviewPanelUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectAssetsOverview? overview,
}) {
  if (!projectSelected) {
    return const ShortVideoAssetsOverviewPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoAssetsOverviewPanelUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoAssetsOverviewLoadingHeadline,
      detail: l10n.shortVideoAssetsOverviewLoadingDetail,
    );
  }
  if (overview == null) {
    return ShortVideoAssetsOverviewPanelUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoAssetsOverviewUnavailableHeadline,
      detail: l10n.shortVideoAssetsOverviewUnavailableDetail,
    );
  }
  final lines = <String>[];
  for (final g in overview.byAssetType) {
    final ids = <int>{};
    for (final item in g.items) {
      ids.addAll(item.linkedScriptNumericIds);
    }
    final sorted = ids.toList()..sort();
    final scriptPart = sorted.isEmpty
        ? l10n.shortVideoAssetsOverviewNoLinkedScripts
        : '${l10n.shortVideoAssetsOverviewScriptsPrefix}'
              '${sorted.take(8).map((n) => '#$n').join('·')}'
              '${sorted.length > 8 ? l10n.shortVideoAssetsOverviewScriptsEllipsis : ''}';
    lines.add(
      l10n.shortVideoAssetsOverviewTypeLine(
        shortVideoAssetTypeOverviewLabel(l10n, g.assetType),
        g.items.length,
        scriptPart,
      ),
    );
  }
  return ShortVideoAssetsOverviewPanelUi(
    visible: true,
    headline: l10n.shortVideoAssetsOverviewHeadline(overview.totalCount),
    typeLines: lines,
    detail: l10n.shortVideoAssetsOverviewFooter,
  );
}

ShortVideoCandidateComparePanelUi buildShortVideoCandidateComparePanelUi({
  required AppLocalizations l10n,
  required bool projectSelected,
  required bool loadingProjectOverview,
  required List<ProductionStoryboardItemV1> storyboardRows,
  required ProjectShortVideoReadiness? readiness,
  required List<QualityReview> reviews,
  required bool isLiveAction,
  required void Function(ProductionStoryboardItemV1 row)? onSetCurrent,
  void Function(ProductionStoryboardItemV1 row, String videoUrl)?
      onSelectCandidateVideo,
  required VoidCallback? onOpenProductionWorkspace,
}) {
  if (!projectSelected) {
    return const ShortVideoCandidateComparePanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return ShortVideoCandidateComparePanelUi(
      visible: true,
      loading: true,
      headline: l10n.shortVideoCandidateCompareLoadingHeadline,
      detail: l10n.shortVideoCandidateCompareLoadingDetail,
    );
  }
  if (storyboardRows.isEmpty) {
    return ShortVideoCandidateComparePanelUi(
      visible: true,
      unavailable: true,
      headline: l10n.shortVideoCandidateCompareUnavailableHeadline,
      detail: l10n.shortVideoCandidateCompareUnavailableDetail,
    );
  }

  final readinessByStoryboard = <int, StoryboardShortVideoReadiness>{};
  for (final row in readiness?.storyboards ?? const <StoryboardShortVideoReadiness>[]) {
    readinessByStoryboard[row.storyboardNumericId] = row;
  }
  final reviewsByStoryboard = <String, List<QualityReview>>{};
  for (final row in reviews) {
    final targetId = (row.targetId ?? '').trim();
    if (targetId.isEmpty) continue;
    reviewsByStoryboard.putIfAbsent(targetId, () => <QualityReview>[]).add(row);
  }

  final sortedRows = List<ProductionStoryboardItemV1>.from(storyboardRows)
    ..sort((a, b) {
      final ar = readinessByStoryboard[a.id];
      final br = readinessByStoryboard[b.id];
      final aBlocked = ar != null && !ar.readyForGeneration;
      final bBlocked = br != null && !br.readyForGeneration;
      if (aBlocked != bBlocked) {
        return aBlocked ? -1 : 1;
      }
      final byScript = (a.scriptId ?? 0).compareTo(b.scriptId ?? 0);
      if (byScript != 0) return byScript;
      return (a.sbIndex ?? a.id).compareTo(b.sbIndex ?? b.id);
    });

  final items = sortedRows.take(4).map((row) {
    final shotReadiness = readinessByStoryboard[row.id];
    final shotReviews = reviewsByStoryboard[row.id.toString()] ?? const <QualityReview>[];
    final badCases = shotReviews.where((review) => review.isBadCase).length;
    final passed = shotReviews.where((review) => review.passed == true).length;
    final readinessLine = shotReadiness == null
        ? l10n.shortVideoCandidateCompareReadinessNoData
        : shotReadiness.readyForGeneration
        ? l10n.shortVideoCandidateCompareReadinessReady
        : l10n.shortVideoCandidateCompareReadinessBlocked(
            shotReadiness.blockingReasons
                .map((c) => labelShortVideoBlockingReasonLocalized(l10n, c))
                .join('、'),
          );
    final qualityLine = shotReviews.isEmpty
        ? (isLiveAction
              ? l10n.shortVideoCandidateQualityNoReviewsLive
              : l10n.shortVideoCandidateQualityNoReviewsAnimated)
        : l10n.shortVideoCandidateQualitySummary(
            shotReviews.length,
            passed,
            badCases,
          );
    final candidateUrls = row.mediaSlots?.candidateVideoUrls ?? const <String>[];
    return ShortVideoCandidateCompareItemUi(
      storyboardNumericId: row.id,
      scriptNumericId: row.scriptId,
      referenceImageUrl: row.mediaSlots?.referenceOrPreviewFrameUrl,
      selectedVideoUrl: row.mediaSlots?.currentVideoUrl,
      candidateVideoUrls: candidateUrls,
      liveActionReferenceShotUrls: row.liveActionReferenceShotUrls,
      readinessLine: readinessLine,
      qualityLine: qualityLine,
      writebackLine: formatShortVideoWritebackLine(l10n, row.mediaSlots?.lastWriteback),
      onSetCurrent: (row.mediaSlots?.currentVideoUrl ?? '').trim().isEmpty
          ? null
          : () => onSetCurrent?.call(row),
      onSelectCandidateVideo: onSelectCandidateVideo == null
          ? null
          : (url) => onSelectCandidateVideo(row, url),
      onOpenRework: onOpenProductionWorkspace,
    );
  }).toList(growable: false);

  return ShortVideoCandidateComparePanelUi(
    visible: true,
    headline: l10n.shortVideoCandidateCompareHeadline(items.length),
    detail: isLiveAction
        ? l10n.shortVideoCandidateCompareDetailLive
        : l10n.shortVideoCandidateCompareDetailAnimated,
    items: items,
  );
}
