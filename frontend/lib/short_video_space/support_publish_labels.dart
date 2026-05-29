part of 'support_publish_api.dart';

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
List<String> shortVideoExportPublishFacetLabels(
  AppLocalizations l10n,
  ShortVideoExportPlatformFacet facet,
) {
  final out = <String>[];
  if (facet.missingCover) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetMissingCover);
  }
  if (facet.missingPlatformCopy) {
    out.add(l10n.shortVideoSpacePublishExportCheckFacetMissingPlatformCopy);
  }
  return out;
}

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
    case 'missing_cover':
      return l10n.shortVideoSpacePublishExportIssueMissingCover;
    case 'missing_target_platforms':
      return l10n.shortVideoSpacePublishExportIssueMissingTargetPlatforms;
    case 'missing_platform_copy_block':
      return l10n.shortVideoSpacePublishExportIssueMissingPlatformCopy;
    case 'unknown_platform':
      return l10n.shortVideoSpacePublishExportIssueUnknownPlatform;
    default:
      return code;
  }
}

List<ShortVideoExportPublishPlatformGapUi> buildShortVideoExportPublishPlatformGapUi(
  AppLocalizations l10n,
  ShortVideoExportPublishFacets facets, {
  bool blockingOnly = false,
}) {
  var platformFacets = facets.platformFacets;
  if (blockingOnly) {
    platformFacets =
        platformFacets.where((f) => f.hasBlocking).toList(growable: false);
  }
  return platformFacets
      .map((f) {
        final labels = shortVideoExportPublishFacetLabels(l10n, f);
        final facetSummary = labels.isEmpty
            ? f.gapCodes.map((c) => shortVideoExportIssueLabel(l10n, c)).join(' · ')
            : labels.join(' · ');
        return ShortVideoExportPublishPlatformGapUi(
          title: l10n.shortVideoSpacePublishExportCheckPublishPlatformGapTitle(
            f.platformId,
          ),
          facetSummary: facetSummary,
          hasBlocking: f.hasBlocking,
        );
      })
      .toList(growable: false);
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
