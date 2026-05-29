part of 'support_publish_api.dart';

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
  final publishPlatformGapEntries = buildShortVideoExportPublishPlatformGapUi(
    l10n,
    exportCheck.publishFacets,
    blockingOnly: true,
  );
  final publishBlockingLines = exportCheck.publishIssues
      .where((i) => i.severity == 'blocking')
      .take(8)
      .map((i) {
        final platform = (i.platformId ?? '').trim();
        final platformPart = platform.isEmpty
            ? ''
            : ' · $platform';
        return '${shortVideoExportIssueLabel(l10n, i.code)}$platformPart · ${i.detail}';
      })
      .toList(growable: false);
  final publishWarningLines = exportCheck.publishIssues
      .where((i) => i.severity == 'warning')
      .take(8)
      .map((i) {
        final platform = (i.platformId ?? '').trim();
        final platformPart = platform.isEmpty
            ? ''
            : ' · $platform';
        return '${shortVideoExportIssueLabel(l10n, i.code)}$platformPart · ${i.detail}';
      })
      .toList(growable: false);
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
    publishPlatformGapEntries: publishPlatformGapEntries,
    publishBlockingLines: publishBlockingLines,
    publishWarningLines: publishWarningLines,
    blockingLines: storyboardGapEntries.isEmpty ? blockingLines : const <String>[],
    warningLines: warningLines,
    detail: detail,
    exportReady: exportCheck.exportReady,
  );
}

/// Space 候选资产确认卡：消费 GET .../assets-overview 的 candidate_counts
