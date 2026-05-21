import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api/project/overview_models_assembly.dart';
import 'creator_journey_telemetry.dart';
import 'studio_step.dart';

/// Top blocking export issues for the review-pack → export bridge (T9).
List<ShortVideoExportCheckIssue> reviewPackTopBlockingExportIssues(
  ProjectShortVideoExportCheck? check, {
  int limit = 3,
}) {
  if (check == null) {
    return const <ShortVideoExportCheckIssue>[];
  }
  return check.issues
      .where((issue) => issue.severity.trim().toLowerCase() == 'blocking')
      .take(limit)
      .toList(growable: false);
}

/// Explains when final export is allowed and what is still missing.
class StudioReviewPackExportBridge extends StatelessWidget {
  const StudioReviewPackExportBridge({
    super.key,
    required this.projectNumericId,
    required this.exportCheck,
    this.exportCheckLoadFailed = false,
  });

  final int projectNumericId;
  final ProjectShortVideoExportCheck? exportCheck;
  final bool exportCheckLoadFailed;

  void _openDeliver(BuildContext context, {required String tab}) {
    CreatorJourneyTelemetry.record(
      CreatorJourneyEvent(
        'review_pack_open_deliver',
        <String, Object?>{
          'project_id': projectNumericId,
          'tab': tab,
          'export_ready': exportCheck?.exportReady ?? false,
        },
      ),
    );
    context.go(
      '/projects/$projectNumericId/${StudioStep.deliver.slug}?tab=$tab',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);

    if (exportCheckLoadFailed && exportCheck == null) {
      return const SizedBox.shrink();
    }

    final check = exportCheck;
    if (check == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          l10n.studioReviewPackExportCheckUnavailable,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      );
    }

    final ready = check.exportReady;
    final blocking = reviewPackTopBlockingExportIssues(check);
    final headline = ready
        ? l10n.studioReviewPackExportReadyTitle
        : l10n.studioReviewPackExportBlockedTitle;
    final detail = ready
        ? l10n.studioReviewPackExportReadyDetail
        : l10n.studioReviewPackExportBlockedDetail(
            check.summary.blockingIssueCount,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
        decoration: BoxDecoration(
          color: ready
              ? tokens.primary.withValues(alpha: 0.12)
              : theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ready
                ? tokens.primary.withValues(alpha: 0.35)
                : theme.colorScheme.error.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  ready ? Icons.check_circle_outline : Icons.info_outline,
                  size: 20,
                  color: ready ? tokens.primary : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        headline,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!ready && blocking.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              ...blocking.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${issue.detail.trim().isEmpty ? issue.code : issue.detail}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                StudioPrimaryButton(
                  icon: ready ? Icons.upload_outlined : Icons.build_outlined,
                  label: ready
                      ? l10n.studioReviewPackExportOpenPublish
                      : l10n.studioReviewPackExportFixInAssembly,
                  onPressed: () => _openDeliver(
                    context,
                    tab: ready ? 'publish' : 'assembly',
                  ),
                ),
                if (!ready)
                  OutlinedButton(
                    onPressed: () => _openDeliver(context, tab: 'publish'),
                    child: Text(l10n.studioReviewPackExportViewChecklist),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
