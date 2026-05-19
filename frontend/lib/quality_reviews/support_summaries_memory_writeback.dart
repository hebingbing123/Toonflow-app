import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'quality_reviews_l10n.dart';
import 'support_models.dart';

String? summarizeQualityReviewMemoryWriteback(
  QualityReview row, {
  AppLocalizations? l10n,
}) {
  final feedback = feedbackMemoryMap(row);
  if (feedback == null) return null;

  final loc = qualityReviewsResolveL10n(l10n);

  final action = diagnosticString(feedback, 'action');
  final memoryName = diagnosticString(feedback, 'memoryName');
  final clearedMemoryName = diagnosticString(feedback, 'clearedMemoryName');
  final storyboardId = diagnosticInt(feedback, 'storyboardId');
  final removedRows = diagnosticInt(feedback, 'removedRows');
  final removedChars = diagnosticInt(feedback, 'removedChars');
  final removedVisualRows = diagnosticInt(feedback, 'removedVisualRows');
  final removedDuplicateRows = diagnosticInt(feedback, 'removedDuplicateRows');
  final focusTags = diagnosticStringList(feedback, 'focusTags');

  final parts = <String>[];
  switch (action) {
    case 'promoted_selected_memory':
      parts.add(loc.qualityReviewsWritebackPromotedSelected);
      break;
    case 'persisted_rejected_memory':
      parts.add(loc.qualityReviewsWritebackRejectedMemory);
      break;
    case 'replaced_summary_memory':
      parts.add(loc.qualityReviewsWritebackSummaryMemory);
      break;
    case 'promoted_selected_memory_missing_prompt_seed':
      parts.add(loc.qualityReviewsWritebackMissingPromptSeed);
      break;
    case 'promoted_selected_memory_empty':
      parts.add(loc.qualityReviewsWritebackEmptySelectedMemory);
      break;
    default:
      if (action != null) parts.add(action);
  }
  if (storyboardId > 0) {
    parts.add(loc.qualityReviewsShotId(storyboardId));
  }
  if (memoryName != null) {
    parts.add(loc.qualityReviewsWriteMemory(memoryName));
  }
  if (clearedMemoryName != null) {
    parts.add(loc.qualityReviewsClearMemory(clearedMemoryName));
  }
  if (removedChars > 0 || removedRows > 0) {
    parts.add(
      loc.qualityReviewsSlimSummary(
        removedChars,
        removedRows,
        removedDuplicateRows,
        removedVisualRows,
      ),
    );
  }
  final focusSummary = summarizeFeedbackFocusTags(
    focusTags,
    l10n: loc,
  );
  if (focusSummary != null) {
    parts.add(loc.qualityReviewsFocusWatchTag(focusSummary));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
