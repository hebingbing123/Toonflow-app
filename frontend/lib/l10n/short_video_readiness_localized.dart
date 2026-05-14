import 'app_localizations.dart';
import '../rust_api/project/overview_models.dart';

/// Localized blocking-reason labels for [StoryboardShortVideoReadiness] UI.
String labelShortVideoBlockingReasonLocalized(
  AppLocalizations l10n,
  String code,
) {
  final normalized = code.trim().toLowerCase();
  if (normalized.isEmpty) {
    return l10n.scriptEditorStoryboardsReadinessBlockingUnknown('—');
  }
  switch (normalized) {
    case 'missing_basic_slot':
      return l10n.scriptEditorStoryboardsReadinessBlockingMissingBasicSlot;
    case 'missing_prompt_context':
      return l10n.scriptEditorStoryboardsReadinessBlockingMissingPromptContext;
    case 'missing_reference_visual':
      return l10n
          .scriptEditorStoryboardsReadinessBlockingMissingReferenceVisual;
    case 'missing_live_action_reference_shot':
      return l10n
          .scriptEditorStoryboardsReadinessBlockingMissingLiveActionReferenceShot;
    case 'missing_live_action_performance_notes':
      return l10n
          .scriptEditorStoryboardsReadinessBlockingMissingLiveActionPerformanceNotes;
    case 'candidate_pending':
      return l10n.scriptEditorStoryboardsReadinessBlockingCandidatePending;
    case 'blocking_job':
      return l10n.scriptEditorStoryboardsReadinessBlockingBlockingJob;
    default:
      return l10n.scriptEditorStoryboardsReadinessBlockingUnknown(normalized);
  }
}

/// One-line readiness summary for the storyboard workbench (localized).
String formatStoryboardShortVideoReadinessSummaryLocalized(
  AppLocalizations l10n,
  StoryboardShortVideoReadiness row,
) {
  if (row.readyForGeneration) {
    return l10n.scriptEditorStoryboardsReadinessSummaryReady;
  }
  final parts = row.blockingReasons
      .map((c) => labelShortVideoBlockingReasonLocalized(l10n, c))
      .toList();
  if (parts.isEmpty) {
    return l10n.scriptEditorStoryboardsReadinessSummaryPending;
  }
  return l10n.scriptEditorStoryboardsReadinessSummaryBlocked(parts.join('、'));
}
