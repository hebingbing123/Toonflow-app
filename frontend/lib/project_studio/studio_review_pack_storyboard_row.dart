import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/short_video_readiness_localized.dart';
import '../rust_api/project/overview_models.dart';
import 'creator_journey_telemetry.dart';
import 'studio_review_pack_feedback.dart';
import 'studio_step.dart';

typedef ReviewPackFeedbackSubmit = Future<void> Function({
  required StoryboardShortVideoReadiness row,
  required ReviewPackFeedbackStatus status,
  String? comment,
});

/// One storyboard line on the review pack with team feedback controls (T8).
class StudioReviewPackStoryboardRow extends StatelessWidget {
  const StudioReviewPackStoryboardRow({
    super.key,
    required this.row,
    required this.projectNumericId,
    required this.feedback,
    required this.onSubmitFeedback,
  });

  final StoryboardShortVideoReadiness row;
  final int projectNumericId;
  final ReviewPackRowFeedback? feedback;
  final ReviewPackFeedbackSubmit onSubmitFeedback;

  Future<void> _promptCommentAndSubmit(
    BuildContext context,
    ReviewPackFeedbackStatus status,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: feedback?.comment ?? '',
    );
    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.studioReviewPackFeedbackCommentDialogTitle),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.studioReviewPackFeedbackCommentHint,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.studioReviewPackFeedbackSave),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (note == null) {
      return;
    }
    await onSubmitFeedback(
      row: row,
      status: status,
      comment: note.isEmpty ? null : note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final status = feedback?.status ?? ReviewPackFeedbackStatus.pending;
    final statusLabel = reviewPackFeedbackStatusLabel(l10n, status);
    final statusColor = switch (status) {
      ReviewPackFeedbackStatus.approved => tokens.primary,
      ReviewPackFeedbackStatus.needsChanges => Theme.of(context).colorScheme.error,
      ReviewPackFeedbackStatus.flagged => Theme.of(context).colorScheme.error,
      ReviewPackFeedbackStatus.pending => tokens.textSecondary,
    };

    final summary = formatStoryboardShortVideoReadinessSummaryLocalized(
      l10n,
      row,
    );
    final shotLabel = row.sbIndex != null
        ? l10n.projectStudioStoryboardRowTitle(
            row.storyboardNumericId,
            l10n.projectStudioStoryboardShotSuffix(row.sbIndex!),
          )
        : l10n.studioReviewPackStoryboardId(row.storyboardNumericId);

    return Material(
      color: tokens.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(
          '/projects/$projectNumericId/${StudioStep.storyboard.slug}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      shotLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(statusLabel),
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: statusColor.withValues(alpha: 0.45)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  PopupMenuButton<ReviewPackFeedbackStatus>(
                    tooltip: l10n.studioReviewPackFeedbackMenuTooltip,
                    onSelected: (ReviewPackFeedbackStatus value) {
                      CreatorJourneyTelemetry.record(
                        CreatorJourneyEvent(
                          'review_pack_feedback_set',
                          <String, Object?>{
                            'project_id': projectNumericId,
                            'storyboard_id': row.storyboardNumericId,
                            'status': value.name,
                          },
                        ),
                      );
                      _promptCommentAndSubmit(context, value);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<ReviewPackFeedbackStatus>>[
                          PopupMenuItem<ReviewPackFeedbackStatus>(
                            value: ReviewPackFeedbackStatus.approved,
                            child: Text(l10n.studioReviewPackFeedbackSetApproved),
                          ),
                          PopupMenuItem<ReviewPackFeedbackStatus>(
                            value: ReviewPackFeedbackStatus.needsChanges,
                            child: Text(l10n.studioReviewPackFeedbackSetNeedsChanges),
                          ),
                          PopupMenuItem<ReviewPackFeedbackStatus>(
                            value: ReviewPackFeedbackStatus.flagged,
                            child: Text(l10n.studioReviewPackFeedbackSetFlagged),
                          ),
                        ],
                    icon: const Icon(Icons.rate_review_outlined, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    row.readyForGeneration
                        ? Icons.check_circle_outline
                        : Icons.hourglass_empty_rounded,
                    size: 20,
                    color: row.readyForGeneration
                        ? tokens.primary
                        : tokens.textSecondary,
                  ),
                ],
              ),
              if (row.scriptNumericId != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  l10n.studioReviewPackScriptLine(row.scriptNumericId!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
              ],
              if (feedback?.comment != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  feedback!.comment!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                summary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
