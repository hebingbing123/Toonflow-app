import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'support_models.dart';

String? summarizeQualityReviewMemoryWriteback(
  QualityReview row, {
  AppLocalizations? l10n,
}) {
  final feedback = feedbackMemoryMap(row);
  if (feedback == null) return null;

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
      parts.add(
        l10n?.qualityReviewsWritebackPromotedSelected ??
            'promoted selected memory',
      );
      break;
    case 'persisted_rejected_memory':
      parts.add(
        l10n?.qualityReviewsWritebackRejectedMemory ??
            'bad-case memory writeback',
      );
      break;
    case 'replaced_summary_memory':
      parts.add(
        l10n?.qualityReviewsWritebackSummaryMemory ??
            'review summary writeback',
      );
      break;
    case 'promoted_selected_memory_missing_prompt_seed':
      parts.add(
        l10n?.qualityReviewsWritebackMissingPromptSeed ??
            'selected memory missing prompt seed',
      );
      break;
    case 'promoted_selected_memory_empty':
      parts.add(
        l10n?.qualityReviewsWritebackEmptySelectedMemory ??
            'selected memory yielded no effective fragment',
      );
      break;
    default:
      if (action != null) parts.add(action);
  }
  if (storyboardId > 0) {
    parts.add(l10n?.qualityReviewsShotId(storyboardId) ?? 'shot $storyboardId');
  }
  if (memoryName != null) {
    parts.add(
      l10n?.qualityReviewsWriteMemory(memoryName) ?? 'write=$memoryName',
    );
  }
  if (clearedMemoryName != null) {
    parts.add(
      l10n?.qualityReviewsClearMemory(clearedMemoryName) ??
          'clear=$clearedMemoryName',
    );
  }
  if (removedChars > 0 || removedRows > 0) {
    parts.add(
      l10n?.qualityReviewsSlimSummary(
            removedChars,
            removedRows,
            removedDuplicateRows,
            removedVisualRows,
          ) ??
          'slim $removedChars chars / $removedRows items (dup $removedDuplicateRows / visual-only $removedVisualRows)',
    );
  }
  final focusSummary = summarizeFeedbackFocusTags(focusTags, l10n: l10n);
  if (focusSummary != null) {
    parts.add(
      l10n?.qualityReviewsFocusWatchTag(focusSummary) ?? 'watch=$focusSummary',
    );
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
